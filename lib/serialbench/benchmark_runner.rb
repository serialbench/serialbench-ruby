# frozen_string_literal: true

require 'benchmark'
require 'benchmark/ips'
require_relative 'serializers'
require_relative 'models/benchmark_result'

begin
  require 'memory_profiler'
rescue LoadError
  # Memory profiler is optional
end

module Serialbench
  class BenchmarkRunner
    attr_reader :environment_config, :benchmark_config, :serializers, :test_data, :results

    def initialize(benchmark_config:, environment_config:)
      @environment_config = environment_config
      @benchmark_config = benchmark_config
      @serializers = Serializers.available
      @test_data = {}
      @results = []
      validate_operations!
      load_test_data
    end

    # Each operation maps to a lambda. Adding an operation = one entry.
_DEFAULT_RNG_SCHEMA = <<'RNG'.freeze
<?xml version="1.0" encoding="UTF-8"?>
<grammar xmlns="http://relaxng.org/ns/structure/1.0" datatypeLibrary="http://www.w3.org/2001/XMLSchema-datatypes">
  <start>
    <choice>
      <ref name="config"/>
      <ref name="users"/>
      <ref name="dataset"/>
    </choice>
  </start>

  <define name="config">
    <element name="config">
      <element name="database">
        <element name="host"><text/></element>
        <element name="port"><data type="integer"/></element>
        <element name="name"><text/></element>
        <element name="user"><text/></element>
        <element name="password"><text/></element>
      </element>
      <element name="cache">
        <element name="enabled"><data type="boolean"/></element>
        <element name="ttl"><data type="integer"/></element>
      </element>
    </element>
  </define>

  <define name="users">
    <element name="users">
      <oneOrMore>
        <ref name="user"/>
      </oneOrMore>
    </element>
  </define>

  <define name="user">
    <element name="user">
      <attribute name="id"><data type="integer"/></attribute>
      <element name="name"><text/></element>
      <element name="email"><text/></element>
      <element name="created_at"><text/></element>
      <element name="profile">
        <element name="age"><data type="integer"/></element>
        <element name="city"><text/></element>
        <element name="preferences">
          <element name="theme"><text/></element>
          <element name="notifications"><data type="boolean"/></element>
        </element>
      </element>
    </element>
  </define>

  <define name="dataset">
    <element name="dataset">
      <element name="header">
        <element name="created"><text/></element>
        <element name="count"><data type="integer"/></element>
        <element name="format"><text/></element>
      </element>
      <element name="records">
        <oneOrMore>
          <ref name="record"/>
        </oneOrMore>
      </element>
    </element>
  </define>

  <define name="record">
    <element name="record">
      <attribute name="id"><data type="integer"/></attribute>
      <element name="timestamp"><text/></element>
      <element name="data">
        <element name="field1"><text/></element>
        <element name="field2"><data type="integer"/></element>
        <element name="field3"><text/></element>
        <element name="nested">
          <oneOrMore><element name="item"><text/></element></oneOrMore>
        </element>
      </element>
      <element name="metadata">
        <element name="source"><text/></element>
        <element name="version"><text/></element>
        <element name="checksum"><text/></element>
      </element>
    </element>
  </define>
</grammar>
RNG

_DEFAULT_XSLT_STYLESHEET = <<'XSL'.freeze
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="xml" indent="yes"/>
  <xsl:template match="/">
    <report>
      <xsl:apply-templates select="//user | //record | //database | //cache"/>
      <total>
        <xsl:value-of select="count(//user) + count(//record)"/>
      </total>
    </report>
  </xsl:template>
  <xsl:template match="user">
    <row kind="user" id="{@id}" label="{name}"/>
  </xsl:template>
  <xsl:template match="record">
    <row kind="record" id="{@id}" label="{data/field1}"/>
  </xsl:template>
  <xsl:template match="database">
    <row kind="database" label="{name}"/>
  </xsl:template>
  <xsl:template match="cache">
    <row kind="cache" label="{ttl}"/>
  </xsl:template>
</xsl:stylesheet>
XSL

_DEFAULT_XSLT30_STYLESHEET = <<'XSL30'.freeze
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="xs"
                version="3.0">
  <xsl:output method="xml" indent="yes"/>
  <xsl:template match="/">
    <report30>
      <xsl:iterate select="//user | //record | //database | //cache">
        <xsl:param name="labels" as="xs:string*" select="()"/>
        <xsl:on-completion>
          <joined><xsl:value-of select="string-join($labels, ', ')"/></joined>
          <count><xsl:value-of select="count($labels)"/></count>
        </xsl:on-completion>
        <xsl:variable name="label" select="string((name, data/field1, ttl)[1])"/>
        <xsl:if test="$label != ''">
          <row kind="{local-name()}" label="{upper-case($label)}"/>
        </xsl:if>
        <xsl:next-iteration>
          <xsl:with-param name="labels" select="if ($label != '') then ($labels, $label) else $labels"/>
        </xsl:next-iteration>
      </xsl:iterate>
    </report30>
  </xsl:template>
</xsl:stylesheet>
XSL30

    XPATH_QUERIES = ['//user | //record', "//user[@id='101']", '//preferences/theme'].freeze
    XQUERY_EXPRESSIONS = ['count(//user | //record)', "//record[@id='101']/data/field1", '//user[profile/age > 40]/name'].freeze
    RNG_SCHEMA = File.expand_path('test_data/schema.rng', Dir.pwd).then { |p| File.exist?(p) ? File.read(p) : _DEFAULT_RNG_SCHEMA }
    XSLT_STYLESHEET = File.expand_path('test_data/transform.xsl', Dir.pwd).then { |p| File.exist?(p) ? File.read(p) : _DEFAULT_XSLT_STYLESHEET }
    XSLT30_STYLESHEET = File.expand_path('test_data/transform30.xsl', Dir.pwd).then { |p| File.exist?(p) ? File.read(p) : _DEFAULT_XSLT30_STYLESHEET }

    OPERATIONS = {
      'parsing' => ->(s, data) { s.parse(data) },
      'generation' => ->(s, data) { s.generate(s.parse(data)) },
      'xpath' => lambda { |s, data|
        doc = s.parse(data)
        XPATH_QUERIES.each { |q| s.xpath_query(doc, q) }
      },
      'xquery' => lambda { |s, data|
        doc = s.parse(data)
        XQUERY_EXPRESSIONS.each { |x| s.xquery_eval(doc, x) }
      },
      'xslt' => ->(s, data) { s.xslt_apply(data, XSLT_STYLESHEET) },
      'xslt30' => ->(s, data) { s.xslt_apply(data, XSLT30_STYLESHEET) },
      'validation' => ->(s, data) { s.validate(s.parse(data), RNG_SCHEMA) },
      'streaming' => ->(s, data) { s.stream_parse(data) { |_event, _data| } },
    }.freeze

    def run_all_benchmarks
      puts 'Serialbench - Running comprehensive serialization performance tests'
      puts '=' * 70
      puts "Available serializers: #{@serializers.map(&:name).join(', ')}"
      puts "Test formats: #{@benchmark_config.formats.join(', ')}"
      puts "Test data sizes: #{@test_data.keys.join(', ')}"
      puts

      selected = @benchmark_config.operations
      selected = OPERATIONS.keys + ['memory'] if selected.nil? || selected.empty?
      results = {}
      OPERATIONS.each do |name, handler|
        results[name.to_sym] = selected.include?(name) ? run_benchmark_type(name, name, &handler) : []
      end
      results[:memory] = selected.include?('memory') ? run_memory_benchmarks : []

      Models::BenchmarkResult.new(
        serializers: Serializers.information,
        **results
      )
    end

    def run_memory_benchmarks
      puts "\nRunning memory usage benchmarks..."
      return [] unless defined?(::MemoryProfiler)

      run_benchmark_iteration('memory') do |serializer, format, size, data|
        # Memory profiling for parsing. MemoryProfiler disables GC while
        # reporting, so every profiled parse accumulates: ten large-document
        # trees exhaust the 16GB windows runners. One parse fully captures
        # a large document's allocation and retention profile.
        report = ::MemoryProfiler.report do
          profile_iterations(size).times { serializer.parse(data) }
        end

        result = Models::MemoryPerformance.new(
          adapter: serializer.name,
          format: format,
          data_size: size,
          total_allocated: report.total_allocated,
          total_retained: report.total_retained,
          allocated_memory: report.total_allocated_memsize,
          retained_memory: report.total_retained_memsize
        )

        puts "    #{format}/#{serializer.name}: #{(report.total_allocated_memsize / 1024.0 / 1024.0).round(2)}MB allocated"
        result
      end
    end

    private

    def run_benchmark_type(type_name, operation_name, &block)
      puts "#{type_name == 'parsing' ? '' : "\n"}Running #{type_name} benchmarks..."

      run_benchmark_iteration(type_name) do |serializer, format, size, data|
        iterations = get_iterations_for_size(size)

        # Warmup
        3.times { block.call(serializer, data) }

        # Benchmark
        time = Benchmark.realtime do
          iterations.times { block.call(serializer, data) }
        end

        result = Models::IterationPerformance.new(
          adapter: serializer.name,
          format: format,
          data_size: size,
          time_per_iterations: time,
          time_per_iteration: time / iterations.to_f,
          iterations_per_second: iterations.to_f / time,
          iterations_count: iterations
        )

        puts "    #{result.format}/#{result.adapter}: #{(result.time_per_iteration * 1000).round(2)}ms per #{operation_name}"
        result
      end
    end

    def run_benchmark_iteration(type_name)
      results = []

      @test_data.each do |size, format_data|
        puts "  Testing #{size} files..."

        format_data.each do |format, data|
          next unless @benchmark_config.formats.include?(format)

          serializers = get_serializers_for_benchmark_type(type_name, format)

          serializers.each do |serializer|
            next unless serializer.available?

            begin
              result = yield(serializer, format, size, data)
              results << result if result
            rescue StandardError => e
              puts "    #{format}/#{serializer.name}: ERROR - #{e.message}"
            ensure
              # Free the previous adapter's documents before the next one
              # parses + profiles; without this, six adapters' trees coexist
              # and windows runners OOM during the xml memory pass.
              GC.start
            end
          end
        end
      end

      results
    end

    def get_serializers_for_benchmark_type(type_name, format)
      serializers = Serializers.for_format(format)

      case type_name
      when 'parsing', 'memory'
        serializers.select { |s| s.supports?(:parse) }
      when 'generation'
        serializers.select { |s| s.supports?(:generate) }
      when 'streaming'
        serializers.select { |s| s.supports?(:sax) || s.supports?(:streaming) }
      when 'xpath'
        serializers.select { |s| s.supports?(:xpath) }
      when 'xquery'
        serializers.select { |s| s.supports?(:xquery) }
      when 'xslt'
        serializers.select { |s| s.supports?(:xslt) }
      when 'validation'
        serializers.select { |s| s.supports?(:validation) }
      when 'xslt30'
        serializers.select { |s| s.supports?(:xslt30) }
      else
        serializers
      end
    end

    def get_iterations_for_size(size)
      iterations = @benchmark_config.iterations
      case size.to_s
      when 'small' then iterations.small
      when 'medium' then iterations.medium
      when 'large' then iterations.large
      else raise ArgumentError, "no iteration count configured for #{size}"
      end
    end

    def profile_iterations(size)
      size.to_s == 'large' ? 1 : 10
    end

    def validate_operations!
      unknown = (@benchmark_config.operations || []) - (OPERATIONS.keys + ['memory'])
      return if unknown.empty?

      raise ArgumentError, "unknown operations #{unknown.inspect}; expected: #{OPERATIONS.keys.join(', ')}, memory"
    end

    def load_test_data
      @test_data = TestData.load(@benchmark_config)
    end
  end
end

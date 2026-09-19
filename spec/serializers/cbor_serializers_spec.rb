# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Serialbench::Serializers::Cbor do
  describe 'registration' do
    it 'exposes the cbor format adapters' do
      names = Serialbench::Serializers.for_format(:cbor).map(&:name)
      expect(names).to include('cbor', 'yeptris-cbor')
    end
  end

  describe Serialbench::Serializers::Cbor::CborSerializer do
    subject(:serializer) { described_class.instance }

    it 'round-trips plain data' do
      skip 'cbor gem unavailable' unless serializer.available?

      obj = { 'users' => [{ 'id' => 1, 'nested' => { 'a' => [1, 2] } }] }
      expect(serializer.parse(serializer.generate(obj))).to eq(obj)
    end

    it 'parses and generates' do
      skip 'cbor gem unavailable' unless serializer.available?

      expect(serializer.supports?(:parse)).to be(true)
      expect(serializer.supports?(:generate)).to be(true)
    end
  end

  describe Serialbench::Serializers::Cbor::YeptrisSerializer do
    subject(:serializer) { described_class.instance }

    it 'decodes the canonical fixtures' do
      skip 'yeptris CBOR unavailable' unless serializer.available?
      skip 'canonical fixtures not cloned' unless File.exist?('test_data/small.cbor')

      decoded = serializer.parse(File.binread('test_data/small.cbor'))
      expect(decoded).to be_a(Hash)
    end

    it 'is parse-only while dump segfaults upstream' do
      skip 'yeptris CBOR unavailable' unless serializer.available?

      expect(serializer.supports?(:parse)).to be(true)
      expect(serializer.supports?(:generate)).to be(false)
    end
  end
end

require 'spec_helper'
require 'hiera/util'

describe "Hiera" do
  let!(:fixtures) { File.join(HieraSpec::FIXTURE_DIR, 'interpolate') }
  let!(:fixture_data) { File.join(fixtures, 'data') }
  let(:hiera) { Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml')) }

  before(:each) do
    Hiera::Util.expects(:var_dir).at_most(3).returns(fixture_data)
  end

  context "when doing interpolation" do
    it 'should prevent endless recursion' do
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect do
        hiera.lookup('foo', nil, {})
      end.to raise_error Hiera::InterpolationLoop, 'Lookup recursion detected in [hiera("bar"), hiera("foo")]'
    end

    it 'produces a nested hash with arrays from nested aliases with hashes and arrays' do
      Hiera::Util.expects(:var_dir).at_least_once.returns(File.join(fixtures, 'data'))
      hiera = Hiera.new(:config => File.join(fixtures, 'config', 'hiera.yaml'))
      expect(hiera.lookup('root', nil, {}, nil, :hash)).to eq({'a'=>{'aa'=>{'b'=>{'bb'=>['text']}}}})
    end
  end

  context "when not finding value for interpolated key" do
    it 'should resolve the interpolation to an empty string' do
      expect(hiera.lookup('niltest', nil, {})).to eq('Missing key ##. Key with nil ##')
    end
  end

  context "when there are empty interpolations %{} in data" do
    it 'should should produce an empty string for the interpolation' do
      expect(hiera.lookup('empty_interpolation', nil, {})).to eq('clownshoe')
    end

    it 'the empty interpolation can be escaped' do
      expect(hiera.lookup('escaped_empty_interpolation', nil, {})).to eq('clown%{shoe}s')
    end

    it 'the value can consist of only an empty escape' do
      expect(hiera.lookup('only_empty_interpolation', nil, {})).to eq('')
    end

    it 'the value can consist of an empty namespace %{::}' do
      expect(hiera.lookup('empty_namespace', nil, {})).to eq('')
    end

    it 'the value can consist of whitespace %{ :: }' do
      expect(hiera.lookup('whitespace1', nil, {})).to eq('')
    end

    it 'the value can consist of whitespace %{  }' do
      expect(hiera.lookup('whitespace2', nil, {})).to eq('')
    end
  end

  context "when doing interpolation with override" do
    let(:fixtures) { File.join(HieraSpec::FIXTURE_DIR, 'override') }

    it 'should resolve interpolation using the override' do
      expect(hiera.lookup('foo', nil, {}, 'alternate')).to eq('alternate')
    end
  end

  context 'when doing interpolation in config file' do
    let(:hiera) { Hiera.new(:config => File.join(fixtures, 'config', 'hiera_iplm_hiera.yaml')) }

    it 'should allow and resolve a correctly configured interpolation using "hiera" method' do
      expect(hiera.lookup('foo', nil, {})).to eq('Foo')
    end

    it 'should issue warning when interpolation methods are used' do
      Hiera.expects(:warn).with('Use of interpolation methods in hiera configuration file is deprecated').at_least_once
      expect(hiera.lookup('foo', nil, {})).to eq('Foo')
    end
  end

  context 'when doing interpolation in bad config file' do
    let(:hiera) { Hiera.new(:config => File.join(fixtures, 'config', 'hiera_iplm_hiera_bad.yaml')) }

    it 'should detect interpolation recursion when using "hiera" method' do
      expect{ hiera.lookup('foo', nil, {}) }.to raise_error(Hiera::InterpolationLoop, "Lookup recursion detected in [hiera('role')]")
    end
  end
end

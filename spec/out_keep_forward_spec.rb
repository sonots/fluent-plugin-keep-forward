# encoding: UTF-8
require_relative 'spec_helper'

shared_context 'keep_forward_init' do
  before { Fluent::Test.setup }
  CONFIG = %[
    <server>
      host localhost
      port 24224
    </server>
    <server>
      host localhost
      port 24225
    </server>
  ]
  let(:tag) { 'syslog.host1' }
  let(:es)  { Object.new }
  let(:config) { CONFIG }
  let(:driver) { Fluent::Test::OutputTestDriver.new(Fluent::KeepForwardOutput, tag).configure(config).instance }
end

shared_context 'keep_forward_try_once' do
  before do
    # simpler version of Fluent::ForwardOutput#start method
    driver.instance_variable_set(:@rand_seed, Random.new.seed)
    driver.send(:rebuild_weight_array)
    driver.instance_variable_set(:@rr, 0)
    # try send once to cache keep_node
    driver.stub(:send_data) # stub
    driver.write_objects(tag, es)
  end
  let!(:keep_node) { driver.instance_variable_get(:@node)[tag] }
  let!(:unkeep_node) { (driver.instance_variable_get(:@nodes) - [keep_node]).first }
end

describe Fluent::KeepForwardOutput do
  include_context 'keep_forward_init'
  include_context 'keep_forward_try_once'
  before { driver.should_receive(:send_data).with(target, tag, es) } # mock

  describe 'keep forwarding if no problem?' do
    let(:target) { keep_node }
    it { driver.write_objects(tag, es) }
  end

  describe 'switch if not available?' do
    before { keep_node.available = false }

    let(:target) { unkeep_node }
    it { driver.write_objects(tag, es) }
  end

  describe 'not included in weight_array?' do
    context "switch if recover true" do
      let(:config) {
        CONFIG + %[
          prefer_recover true
        ]
      }
      before { driver.instance_variable_set(:@weight_array, [unkeep_node]) }

      let(:target) { unkeep_node }
      it { driver.write_objects(tag, es) }
    end

    context "not switch if recorver false" do
      let(:config) {
        CONFIG + %[
          prefer_recover false
        ]
      }
      before { driver.instance_variable_set(:@weight_array, [unkeep_node]) }

      let(:target) { keep_node }
      it { driver.write_objects(tag, es) }
    end
  end

  describe 'switch if send_data to keep_node raises?' do
    before { driver.stub(:send_data).with(keep_node, tag, es).and_raise(StandardError) }

    let(:target) { unkeep_node }
    it { driver.write_objects(tag, es) }
  end
end

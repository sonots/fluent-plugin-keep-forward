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
  let(:chunk)  { [1] }
  let(:config) { CONFIG }
  let(:driver) { Fluent::Test::OutputTestDriver.new(Fluent::KeepForwardOutput, tag).configure(config).instance }
end

shared_context 'keep_forward_try_once' do
  before do
    # stub connection
    stub_sock = StringIO.new
    allow(driver).to receive(:connect) { stub_sock }
    allow(stub_sock). to receive(:setsockopt)
    allow(driver).to receive(:sock_write) { nil }
    allow_any_instance_of(Fluent::ForwardOutput::Node).to receive(:heartbeat) { nil }
    # simpler version of Fluent::ForwardOutput#start method
    driver.watcher_interval = 0
    driver.start_watcher
    driver.instance_variable_set(:@rand_seed, Random.new.seed)
    driver.send(:rebuild_weight_array)
    driver.instance_variable_set(:@rr, 0)
    driver.write_objects(tag, chunk)
  end
  after do
    driver.stop_watcher
  end
  let!(:keep_node) { driver.get_node(tag) }
  let!(:another_node) { (driver.instance_variable_get(:@nodes) - [keep_node]).first }
end

shared_examples "keep_node_available" do
  it { driver.write_objects(tag, chunk) }
end

shared_examples "keep_node_not_available" do
  before { keep_node.instance_variable_set(:@available, false) }
  it { driver.write_objects(tag, chunk) }
end

shared_examples "prefer_recover false" do
  let(:config) { CONFIG + %[prefer_recover false] }
  before { driver.instance_variable_set(:@weight_array, [another_node]) }
  it { driver.write_objects(tag, chunk) }
end

shared_context "prefer_recover true" do
  let(:config) { CONFIG + %[prefer_recover true] }
  before { driver.instance_variable_set(:@weight_array, [another_node]) }
  it { driver.write_objects(tag, chunk) }
end

shared_examples "error_occurs" do
  before { allow(driver).to receive(:send_data) {|keep_node, tag, chunk| raise StandardError } }
  it { driver.write_objects(tag, chunk) }
end

describe Fluent::KeepForwardOutput do
  include_context 'keep_forward_init'
  include_context 'keep_forward_try_once'

  describe "keep_node" do
    it_should_behave_like 'keep_node_available' do
      before { expect(driver).to receive(:send_data).with(keep_node, tag, chunk) }
    end
    it_should_behave_like 'keep_node_not_available' do
      before { expect(driver).to receive(:send_data).with(another_node, tag, chunk) }
    end
    it_should_behave_like 'prefer_recover true' do
      before { expect(driver).to receive(:send_data).with(another_node, tag, chunk) }
    end
    it_should_behave_like 'prefer_recover false' do
      before { expect(driver).to receive(:send_data).with(keep_node, tag, chunk) }
    end
    it_should_behave_like 'error_occurs' do
      before { allow(driver).to receive(:weight_send_data).with(tag, chunk) } # re-call weight_send_data
    end
  end

  describe "keepalive false" do
    let(:config) { CONFIG + %[keepalive false] }
    it_should_behave_like 'keep_node_available' do
      before { expect(driver).to receive(:reconnect) }
    end
    it_should_behave_like 'keep_node_not_available' do
      before { expect(driver).to receive(:reconnect) }
    end
    it_should_behave_like 'prefer_recover true' do
      let(:config) { CONFIG + %[prefer_recover true\nkeepalive false] }
      before { expect(driver).to receive(:reconnect) }
    end
    it_should_behave_like 'prefer_recover false' do
      let(:config) { CONFIG + %[prefer_recover false\nkeepalive false] }
      before { expect(driver).to receive(:reconnect) }
    end
  end

  describe "keepalive true" do
    let(:config) { CONFIG + %[keepalive true] }
    it_should_behave_like 'keep_node_available' do
      before { expect(driver).not_to receive(:reconnect) }
    end
    it_should_behave_like 'keep_node_not_available' do
      before { expect(driver).to receive(:reconnect) }
    end
    it_should_behave_like 'prefer_recover true' do
      let(:config) { CONFIG + %[prefer_recover true\nkeepalive true] }
      before { expect(driver).to receive(:reconnect) }
    end
    it_should_behave_like 'prefer_recover false' do
      let(:config) { CONFIG + %[prefer_recover false\nkeepalive true] }
      before { expect(driver).not_to receive(:reconnect) }
    end
  end

  describe "keepalive_time expired" do
    let(:config) { CONFIG + %[keepalive true\nkeepalive_time 30] }
    before { Delorean.jump 30 }
    it_should_behave_like 'keep_node_available' do
      before { sleep 1; expect(driver).to receive(:reconnect) }
    end
    pending "fix RumtimeError: can't add a new key into hash during iteration"
    #it_should_behave_like 'keep_node_not_available' do
    #  before { sleep 1; driver.should_receive(:reconnect) }
    #end
    #it_should_behave_like 'prefer_recover true' do
    #  let(:config) { CONFIG + %[prefer_recover true\nkeepalive true\nkeepalive_time 30] }
    #  before { sleep 1; driver.should_receive(:reconnect) }
    #end
    it_should_behave_like 'prefer_recover false' do
      let(:config) { CONFIG + %[prefer_recover false\nkeepalive true\nkeepalive_time 30] }
      before { sleep 1; expect(driver).to receive(:reconnect) }
    end
  end

  describe "heatbeat_type none" do
    let(:config) { CONFIG + %[heartbeat_type none] }
    it { driver.nodes.first.class == Fluent::KeepForwardOutput::NonHeartbeatNode }

    # nodes are always available because heartbeat is off
    it_should_behave_like 'keep_node_available' do
      before { expect(driver).to receive(:send_data).with(keep_node, tag, chunk) }
    end
    it_should_behave_like 'error_occurs' do
      before { allow(driver).to receive(:weight_send_data).with(tag, chunk) } # re-call weight_send_data
    end
  end
end

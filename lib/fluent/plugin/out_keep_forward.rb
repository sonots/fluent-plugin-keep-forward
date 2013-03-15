require 'fluent/plugin/out_forward'

class Fluent::KeepForwardOutput < Fluent::ForwardOutput
  Fluent::Plugin.register_output('keep_forward', self)

  def write_objects(tag, es)
    @node ||= {}
    if @node[tag] and @node[tag].available? and @weight_array.include?(@node[tag])
      begin
        send_data(@node[tag], tag, es)
        return
      rescue
        weight_send_data(tag, es)
      end
    else
      weight_send_data(tag, es)
    end
  end

  def weight_send_data(tag, es)
    error = nil

    wlen = @weight_array.length
    wlen.times do
      @rr = (@rr + 1) % wlen
      node = @weight_array[@rr]

      if node.available?
        begin
          send_data(node, tag, es)
          @node[tag] = node
          $log.info "keep forwarding tag '#{tag}' to node '#{node.name}'", :host=>node.host, :port=>node.port, :weight=>node.weight
          return
        rescue
          # for load balancing during detecting crashed servers
          error = $!  # use the latest error
        end
      end
    end

    @node[tag] = nil
    $log.info "keep forwarding tag '#{tag}' is lost"
    if error
      raise error
    else
      raise "no nodes are available"  # TODO message
    end
  end
end

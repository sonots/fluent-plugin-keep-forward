require 'fluent/plugin/out_forward'

class Fluent::KeepForwardOutput < Fluent::ForwardOutput
  Fluent::Plugin.register_output('keep_forward', self)

  config_param :prefer_recover, :bool, :default => true
  config_param :keepalive, :bool, :default => false
  config_param :keepalive_time, :time, :default => nil # infinite

  # for test
  attr_accessor :watcher_interval

  def configure(conf)
    super

    @node = {}
    @sock = {}
    @sock_expired_at = {}
    @mutex = {}
    @watcher_interval = 1
  end

  def start
    super
    start_watcher
  end

  def shutdown
    super
    stop_watcher
  end

  def start_watcher
    if @keepalive and @keepalive_time
      @watcher = Thread.new(&method(:watch_keepalive_time))
    end
  end

  def stop_watcher
    if @watcher
      @watcher.terminate
      @watcher.join
    end
  end

  # Override
  def write_objects(tag, chunk)
    return if chunk.empty?
    error = nil
    node = @node[tag]

    if node and node.available? and (!@prefer_recover or @weight_array.include?(node))
      begin
        send_data(node, tag, chunk)
        return
      rescue
        weight_send_data(tag, chunk)
      end
    else
      weight_send_data(tag, chunk)
    end
  end

  def weight_send_data(tag, chunk)
    error = nil

    wlen = @weight_array.length
    wlen.times do
      @rr = (@rr + 1) % wlen
      node = @weight_array[@rr]

      if node.available?
        begin
          send_data(node, tag, chunk)
          @node[tag] = node
          return
        rescue
          # for load balancing during detecting crashed servers
          error = $!  # use the latest error
        end
      end
    end

    @node[tag] = nil
    if error
      raise error
    else
      raise "no nodes are available"  # TODO message
    end
  end

  # Override for keepalive
  def send_data(node, tag, chunk)
    get_mutex(node).synchronize do
      sock = get_sock[node]
      unless sock
        sock = reconnect(node)
      end

      begin
        sock_write(sock, tag, chunk)
        node.heartbeat(false)
      rescue Errno::EPIPE, Errno::ECONNRESET, Errno::ECONNABORTED, Errno::ETIMEDOUT => e
        $log.warn "out_keep_forward: #{e.class} #{e.message}"
        sock = reconnect(node)
        retry
      end
    end
  end

  def reconnect(node)
    sock = connect(node)
    opt = [1, @send_timeout.to_i].pack('I!I!')  # { int l_onoff; int l_linger; }
    sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_LINGER, opt)

    opt = [@send_timeout.to_i, 0].pack('L!L!')  # struct timeval
    sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, opt)

    if @keepalive
      get_sock[node] = sock
      get_sock_expired_at[node] = Time.now + @keepalive_time if @keepalive_time
    end

    sock
  end

  def sock_write(sock, tag, chunk)
    # beginArray(2)
    sock.write FORWARD_HEADER

    # writeRaw(tag)
    sock.write tag.to_msgpack  # tag

    # beginRaw(size)
    sz = chunk.size
    #if sz < 32
    #  # FixRaw
    #  sock.write [0xa0 | sz].pack('C')
    #elsif sz < 65536
    #  # raw 16
    #  sock.write [0xda, sz].pack('Cn')
    #else
    # raw 32
    sock.write [0xdb, sz].pack('CN')
    #end

    # writeRawBody(packed_es)
    chunk.write_to(sock)
  end

  # watcher thread callback
  def watch_keepalive_time
    while true
      sleep @watcher_interval
      thread_ids = @sock.keys
      thread_ids.each do |thread_id|
        @sock[thread_id].each do |node, sock|
          @mutex[thread_id][node].synchronize do
            next unless sock_expired_at = @sock_expired_at[thread_id][node]
            next unless Time.now >= sock_expired_at
            sock.close rescue IOError if sock
            @sock[thread_id][node] = nil
            @sock_expired_at[thread_id][node] = nil
          end
        end
      end
    end
  end

  def get_mutex(node)
    thread_id = Thread.current.object_id
    @mutex[thread_id] ||= {}
    @mutex[thread_id][node] ||= Mutex.new
  end

  def get_sock
    @sock[Thread.current.object_id] ||= {}
  end

  def get_sock_expired_at
    @sock_expired_at[Thread.current.object_id] ||= {}
  end
end

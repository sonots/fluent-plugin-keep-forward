require 'fluent/plugin/out_forward'

class Fluent::KeepForwardOutput < Fluent::ForwardOutput
  Fluent::Plugin.register_output('keep_forward', self)

  # To support log_level option implemented by Fluentd v0.10.43
  unless method_defined?(:log)
    define_method("log") { $log }
  end

  config_param :prefer_recover, :bool, :default => true
  config_param :keepalive, :bool, :default => false
  config_param :keepalive_time, :time, :default => nil # infinite
  config_param :keepforward, :default => :one do |val|
    case val.downcase
    when 'one'
      :one
    when 'tag'
      :tag
    else
      raise ConfigError, "out_keep_forward keepforward should be 'one' or 'tag'"
    end
  end

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

  def get_node(tag)
    @node[keepforward(tag)]
  end

  def keepforward(tag)
    @keepforward == :one ? :one : tag
  end

  def cache_node(tag, node)
    @node[keepforward(tag)] = node
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
    node = get_node(tag)

    if node and node.available? and (!@prefer_recover or @weight_array.include?(node))
      begin
        send_data(node, tag, chunk)
        return
      rescue
        node = weight_send_data(tag, chunk, error_node = node)
        cache_node(tag, node)
      end
    else
      node = weight_send_data(tag, chunk, error_node = node)
      cache_node(tag, node)
    end
  end

  def weight_send_data(tag, chunk, error_node = nil)
    error = nil

    if error_node
      sock_close(error_node) if @keepalive and @keepforward == :one
    end

    wlen = @weight_array.length
    wlen.times do
      @rr = (@rr + 1) % wlen
      node = @weight_array[@rr]

      if node.available?
        begin
          send_data(node, tag, chunk)
          return node
        rescue
          # for load balancing during detecting crashed servers
          error = $!  # use the latest error
        end
      end
    end

    cache_node(tag, nil)
    if error
      raise error
    else
      raise "no nodes are available"  # TODO message
    end
  end

  # Override for keepalive
  def send_data(node, tag, chunk)
    get_mutex(node).synchronize do
      sock = get_sock[node] if @keepalive
      unless sock
        sock = reconnect(node)
        cache_sock(node, sock) if @keepalive
      end

      begin
        sock_write(sock, tag, chunk)
        node.heartbeat(false)
      rescue Errno::EPIPE, Errno::ECONNRESET, Errno::ECONNABORTED, Errno::ETIMEDOUT => e
        log.warn "out_keep_forward: send_data failed #{e.class} #{e.message}, try to reconnect", :host=>node.host, :port=>node.port
        sock.close rescue IOError
        sock = reconnect(node)
        cache_sock(node, sock) if @keepalive
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

  def sock_close(node)
    get_mutex(node).synchronize do
      sock = get_sock[node]
      sock.close rescue IOError if sock
      get_sock[node] = nil
      get_sock_expired_at[node] = nil
    end
  end

  def get_mutex(node)
    thread_id = Thread.current.object_id
    @mutex[thread_id] ||= {}
    @mutex[thread_id][node] ||= Mutex.new
  end

  def cache_sock(node, sock)
    get_sock[node] = sock
    get_sock_expired_at[node] = Time.now + @keepalive_time if @keepalive_time
  end

  def get_sock
    @sock[Thread.current.object_id] ||= {}
  end

  def get_sock_expired_at
    @sock_expired_at[Thread.current.object_id] ||= {}
  end
end

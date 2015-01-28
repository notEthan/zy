proc { |p| $:.unshift(p) unless $:.any? { |lp| File.expand_path(lp) == p } }.call(File.expand_path('.', File.dirname(__FILE__)))
require 'helper'

describe(Zy::Server) do
  before do
    server = TCPServer.new('127.0.0.1', 0)
    @server_port = server_port = server.addr[1]
    server.close

    STDERR.puts "firing server"
    Thread.abort_on_exception = true
    @server_thread = Thread.new do
      Zy::Server.new(
        :app => app,
        :bind => "tcp://*:#{server_port}",
      ).start
    end
    STDERR.puts "fired server"
  end
  after do
    @server_thread.kill
  end

  let(:app) do
    proc { |request| {} }
  end

  let(:client_socket) do
    Zy.zmq_context.socket(ZMQ::REQ).tap do |client_socket|
      client_socket.connect("tcp://localhost:#{@server_port}")
    end
  end

  def request_s(*request_strings)
    request_strings.each_with_index do |request_s, i|
      flags = i < request_strings.size - 1 ? ZMQ::SNDMORE : 0
      send_rc = client_socket.send_string(request_s, flags)
      assert(send_rc >= 0)
    end
    reply_strings = []
    more = true
    while more
      reply_message = ZMQ::Message.create || raise(ServerError, "failed to create message (errno = #{ZMQ::Util.errno})")
      recv_rc = client_socket.recvmsg(reply_message)
      assert(recv_rc >= 0)
      reply_strings << reply_message.copy_out_string
      reply_message.close
      more = client_socket.more_parts?
    end
    assert_equal(2, reply_strings.size)
    assert_equal('zy 0.0 json', reply_strings[0])
    JSON.parse(reply_strings[1])
  end

  it 'requests and replies' do
    reply_s = request_s('zy 0.0 json', '{}')
  end

  describe 'internal server error' do
    let(:app) do
      proc { |request| raise }
    end

    it 'internal server errors' do
      reply = request_s('zy 0.0 json', '{}')
      assert_equal({'status' => ['error', 'server', 'internal_error']}, reply)
    end
  end

  it 'rejects non-json' do
    reply = request_s('zy 0.0 json', 'hello!')
    assert_equal({'status' => ['error', 'request', 'not_json']}, reply)
  end

  it 'rejects non-object in json' do
    reply = request_s('zy 0.0 json', '["a request"]')
    assert_equal({'status' => ['error', 'request', 'not_object']}, reply)
  end

  it 'rejects missing request frame' do
    reply = request_s('zy 0.0 json')
    assert_equal({'status' => ['error', 'request', 'request_not_specified']}, reply)
  end

  it 'rejects too many frames' do
    reply = request_s('zy 0.0 json', '{}', '{}')
    assert_equal({'status' => ['error', 'request', 'too_many_frames']}, reply)
  end

  it 'rejects missing format' do
    reply = request_s('zy 0.0', '{}')
    assert_equal({'status' => ['error', 'protocol', 'format_not_specified']}, reply)
  end

  it 'rejects missing version' do
    reply = request_s('zy', '{}')
    assert_equal({'status' => ['error', 'protocol', 'version_not_specified']}, reply)
  end

  it 'rejects missing protocol' do
    reply = request_s('', '{}')
    assert_equal({'status' => ['error', 'protocol', 'protocol_name_not_specified']}, reply)
  end

  it 'rejects unrecognized format' do
    reply = request_s('zy 0.0 xml', '{}')
    assert_equal({'status' => ['error', 'protocol', 'format_not_supported']}, reply)
  end

  it 'rejects unsupported version' do
    reply = request_s('zy 9.0 json', '{}')
    assert_equal({'status' => ['error', 'protocol', 'version_not_supported']}, reply)
  end

  it 'rejects wrong protocol' do
    reply = request_s('http 0.0 json', '{}')
    assert_equal({'status' => ['error', 'protocol', 'protocol_not_supported']}, reply)
  end
end

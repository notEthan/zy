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
        :app => proc { |request| {} },
        :bind => "tcp://*:#{server_port}",
      ).start
    end
    STDERR.puts "fired server"
  end
  after do
    @server_thread.kill
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
    reply_s = ''
    recv_rc = client_socket.recv_string(reply_s)
    assert(recv_rc >= 0)
    reply_s
  end

  it 'requests and replies' do
    reply_s = request_s('zy 0.0 json', '{}')
    reply = JSON.parse(reply_s)
  end

  it 'rejects non-json' do
    reply_s = request_s('zy 0.0 json', 'hello!')
    reply = JSON.parse(reply_s)
    assert_equal({'status' => ['error', 'request', 'not_json']}, reply)
  end

  it 'rejects non-object in json' do
    reply_s = request_s('zy 0.0 json', '["a request"]')
    reply = JSON.parse(reply_s)
    assert_equal({'status' => ['error', 'request', 'not_object']}, reply)
  end

  it 'rejects missing request frame' do
    reply_s = request_s('zy 0.0 json')
    reply = JSON.parse(reply_s)
    assert_equal({'status' => ['error', 'request', 'request_not_specified']}, reply)
  end

  it 'rejects too many frames' do
    reply_s = request_s('zy 0.0 json', '{}', '{}')
    reply = JSON.parse(reply_s)
    assert_equal({'status' => ['error', 'request', 'too_many_frames']}, reply)
  end

  it 'rejects missing format' do
    reply_s = request_s('zy 0.0', '{}')
    reply = JSON.parse(reply_s)
    assert_equal({'status' => ['error', 'protocol', 'format_not_specified']}, reply)
  end

  it 'rejects missing version' do
    reply_s = request_s('zy', '{}')
    reply = JSON.parse(reply_s)
    assert_equal({'status' => ['error', 'protocol', 'version_not_specified']}, reply)
  end

  it 'rejects missing protocol' do
    reply_s = request_s('', '{}')
    reply = JSON.parse(reply_s)
    assert_equal({'status' => ['error', 'protocol', 'protocol_name_not_specified']}, reply)
  end

  it 'rejects unrecognized format' do
    reply_s = request_s('zy 0.0 xml', '{}')
    reply = JSON.parse(reply_s)
    assert_equal({'status' => ['error', 'protocol', 'format_not_supported']}, reply)
  end

  it 'rejects unsupported version' do
    reply_s = request_s('zy 9.0 json', '{}')
    reply = JSON.parse(reply_s)
    assert_equal({'status' => ['error', 'protocol', 'version_not_supported']}, reply)
  end

  it 'rejects wrong protocol' do
    reply_s = request_s('http 0.0 json', '{}')
    reply = JSON.parse(reply_s)
    assert_equal({'status' => ['error', 'protocol', 'protocol_not_supported']}, reply)
  end
end

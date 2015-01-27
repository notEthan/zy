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

  def request_s(request_s)
    send_rc = client_socket.send_string(request_s)
    assert(send_rc >= 0)
    reply_s = ''
    recv_rc = client_socket.recv_string(reply_s)
    assert(recv_rc >= 0)
    reply_s
  end

  it 'requests and replies' do
    reply_s = request_s '{}'
    reply = JSON.parse(reply_s)
  end

  it 'rejects non-json' do
    reply_s = request_s('hello!')
    reply = JSON.parse(reply_s)
    assert_equal({'status' => ['error', 'request', 'not_json']}, reply)
  end

  it 'rejects non-object in json' do
    reply_s = request_s('["a request"]')
    reply = JSON.parse(reply_s)
    assert_equal({'status' => ['error', 'request', 'not_object']}, reply)
  end
end

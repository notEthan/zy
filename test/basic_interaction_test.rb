proc { |p| $:.unshift(p) unless $:.any? { |lp| File.expand_path(lp) == p } }.call(File.expand_path('.', File.dirname(__FILE__)))
require 'helper'

describe(Zy::Server) do
  before do
    STDERR.puts "firing server"
    Thread.abort_on_exception = true
    @server_thread = Thread.new do
      Zy::Server.new(
        :app => proc { |request| {} },
        :bind => 'inproc://zy_test',
      ).start
    end
    STDERR.puts "fired server"
  end
  after do
    @server_thread.kill
  end

  let(:client_socket) do
    Zy.zmq_context.socket(ZMQ::REQ).tap do |client_socket|
      client_socket.connect('inproc://zy_test')
    end
  end

  it('connects') do
    send_rc = client_socket.send_string('{}')
    assert(send_rc >= 0)
    reply_s = ''
    recv_rc = client_socket.recv_string(reply_s)
    assert(recv_rc >= 0)
    reply = JSON.parse(reply_s)
  end
end

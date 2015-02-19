module Zy
  module ZAP
    ENDPOINT = "inproc://zeromq.zap.01"
    VERSION = "1.0"

    autoload :Server, 'zy/zap/server'
    autoload :Request, 'zy/zap/request'
    autoload :Reply, 'zy/zap/reply'
  end
end

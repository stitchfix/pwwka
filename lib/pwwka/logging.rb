module Pwwka
  module Logging

    delegate :fatal, :error, :warn, :info, :debug, to: :logger

    def logger
      Pwwka.configuration.logger
    end

    def logf(format,args)
      level = args.delete(:at) || :info
      message = format % args
      logger.send(level,message)
    end

  end
end

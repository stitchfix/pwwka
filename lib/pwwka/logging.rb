module Pwwka
  module Logging

    delegate :fatal, :error, :warn, :info, :debug, to: :logger

    def logger
      Pwwka.configuration.logger
    end

    LEVELS = {
      fatal: 5,
      error: 4,
      warn: 3,
      info: 2,
      debug: 1,
    }

    def logf(format,args)
      level = args.delete(:at) || :info
      args[:payload] = args["payload"] if args["payload"]
      args[:payload] = "[omitted]" if args[:payload] && LEVELS[Pwwka.configuration.payload_logging.to_sym] > LEVELS[level.to_sym]
      message = format % args
      logger.send(level,message)
    end


  end
end

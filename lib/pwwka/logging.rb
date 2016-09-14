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

    def logf(format,params)
      level = params.delete(:at) || :info
      params[:payload] = params["payload"] if params["payload"]
      params[:payload] = "[omitted]" if params[:payload] && LEVELS[Pwwka.configuration.payload_logging.to_sym] > LEVELS[level.to_sym]
      message = format % params
      logger.send(level,message)
    end


  end
end

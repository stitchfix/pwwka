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
      level = params.delete(:at) || Pwwka.configuration.log_level
      params[:payload] = params["payload"] if params["payload"]
      params[:payload] = "[omitted]" if params[:payload] && omit_payload?
      message = format % params
      logger.send(level,message)
    end

    private

    def omit_payload?
      LEVELS[Pwwka.configuration.payload_logging.to_sym] > LEVELS[level.to_sym] ||
        Pwwka.configuration.receive_raw_payload
    end

  end
end

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
      if Pwwka.configuration.omit_payload_from_log?(level)
        params[:payload] = "[omitted]" if params[:payload]
      end
      message = format % params

      if Pwwka.configuration.log_hooks.select { |key, _value| message.match key }.each { |_key, value| value.call(message, params) }.empty?
        logger.send(level,message)
      end
    end
  end
end

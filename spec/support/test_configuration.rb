require "yaml"
require "socket"
require "timeout"
require "rainbow"

class TestConfiguration
  attr_reader :resque_redis_port, :rabbit_port
  def initialize(docker_compose_file)
    yaml = YAML.load_file(docker_compose_file)

    @resque_redis_port = (ENV["PWWKA_RESQUE_REDIS_PORT"] || yaml["services"]["resque"]["ports"].first.split(/:/)[0]).to_i
    @rabbit_port       = (ENV["PWWKA_RABBIT_PORT"]       || yaml["services"]["rabbit"]["ports"].first.split(/:/)[0]).to_i
  end

  def check_services
    redis_running = is_port_open?("localhost",@resque_redis_port)
    rabbit_running = is_port_open?("localhost",@rabbit_port)
    if !(redis_running && rabbit_port)
      OpenStruct.new(error: "Rabbit and/or Redis is not running - you need to run `docker-compose up` in the root dir",
                     up?: false)
    else
      OpenStruct.new(up?: true)
    end
  end

private

  def is_port_open?(ip, port)
    begin
      Timeout::timeout(1) do
        begin
          s = TCPSocket.new(ip, port)
          s.close
          return true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
          return false
        end
      end
    rescue Timeout::Error
    end

    return false
  end
end

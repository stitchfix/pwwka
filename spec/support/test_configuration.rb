require 'yaml'
class TestConfiguration
  attr_reader :resque_redis_port, :rabbit_port
  def initialize(docker_compose_file)
    yaml = YAML.load_file(docker_compose_file)

    @resque_redis_port = (ENV["PWWKA_RESQUE_REDIS_PORT"] || yaml["services"]["resque"]["ports"].first.split(/:/)[0]).to_i
    @rabbit_port       = (ENV["PWWKA_RABBIT_PORT"]       || yaml["services"]["rabbit"]["ports"].first.split(/:/)[0]).to_i
  end
end

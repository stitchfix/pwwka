# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'pwwka/version'

Gem::Specification.new do |s|
  s.name        = "pwwka"
  s.version     = Pwwka::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Stitch Fix Engineering","Andrew Peterson","Bill Eisenhauer","Dave Copeland","David A McClain","Jonathan Dean","Nick Reavill","Simeon Willbanks"]
  s.email       = ["opensource@stitchfix.com","andy@ndpsoftware.com","bill@stitchfix.com","davetron5000@gmail.com","david@stitchfix.com","jon@jonathandean.com","nick@fluxequalsrad.com","simeon@simeons.net" ]
  s.homepage    = "https://github.com/stitchfix/pwwka"
  s.license     = "MIT"
  s.summary     = "Send and receive messages via RabbitMQ"
  s.description = "The purpose of this gem is to normalise the sending and
  receiving of messages between Rails apps using the shared RabbitMQ
  message bus"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_runtime_dependency("bunny")
  s.add_runtime_dependency("activesupport")
  s.add_runtime_dependency("activemodel")
  s.add_runtime_dependency("mono_logger")
  s.add_development_dependency("rake")
  s.add_development_dependency("rspec")
  s.add_development_dependency("resque")
  s.add_development_dependency("resque-retry")
  s.add_development_dependency("sidekiq")
  s.add_development_dependency("simplecov")
  s.add_development_dependency("resqutils")
  s.add_development_dependency("rainbow")
  s.add_development_dependency('rspec_junit_formatter')
end

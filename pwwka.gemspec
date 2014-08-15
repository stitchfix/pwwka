# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'pwwka/version'

Gem::Specification.new do |s|
  s.name        = "Pwwka"
  s.version     = Pwwka::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Stitch Fix Engineering']
  s.email       = ['eng@stitchfix.com']
  s.homepage    = "http://www.stitchfix.com"
  s.summary     = "Send and receive messages via RabbitMQ"
  s.description = "The purpose of this gem is to normalise the sending and
  receiving of messages between Rails apps using the shared RabbitMQ
  message bus"
  s.rubyforge_project = "pwwka"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_dependency("bunny")
  s.add_dependency("activesupport")
  s.add_dependency("activemodel")
  s.add_dependency("sucker_punch")
  s.add_dependency("mono_logger")
  s.add_development_dependency("rake")
  s.add_development_dependency("rspec")
end

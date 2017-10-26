require 'rubygems/package_task'
require 'rspec/core/rake_task'
require 'bundler'  

$: << File.join(File.dirname(__FILE__),'lib')

include Rake::DSL

gemspec = eval(File.read('pwwka.gemspec'))
Gem::PackageTask.new(gemspec) {}
RSpec::Core::RakeTask.new(:spec)
Bundler::GemHelper.install_tasks

task default: :spec

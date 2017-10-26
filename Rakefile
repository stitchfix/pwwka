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

task :tag do
  require "pwwka/version"
  version = "v#{Pwwka::VERSION}"
  sh("git tag #{version}")     { |ok,res| fail res.inspect unless ok }
  sh("git push --tags origin") { |ok,res| fail res.inspect unless ok }
end
task release: [ :build, :tag ] do
  sh("gem push --key rubygems_stitchfix_api_key pkg/pwwka-#{Pwwka::VERSION}.gem") { |ok,res| fail res.inspect unless ok }
end

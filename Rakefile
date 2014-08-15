require 'rubygems/package_task'
require 'rspec/core/rake_task'

$: << File.join(File.dirname(__FILE__),'lib')
require 'stitch_fix/y/tasks'

include Rake::DSL

gemspec = eval(File.read('pwwka.gemspec'))
Gem::PackageTask.new(gemspec) {}
RSpec::Core::RakeTask.new(:spec)
StitchFix::Y::ReleaseTask.new(gemspec)
StitchFix::Y::VersionTask.new(gemspec)

task :default => :spec

task :console do
  require 'irb'
  require 'irb/completion'
  require 'stitch_fix/message_handler'
  ARGV.clear
  IRB.start
end


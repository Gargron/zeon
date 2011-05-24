require 'rake'
require 'jeweler'
require 'rspec/core/rake_task'
require 'rake/rdoctask'

RSpec::Core::RakeTask.new('spec') do |t|
  t.rspec_opts = ['--colour --backtrace']
  t.pattern = 'spec.rb'
end

task :console do
  require 'app'
  require 'irb'
  ARGV.clear
  IRB.start
end

task :reprocess do
  require 'app'
  Activity.each do |b|
    if b.image?
      b.image.reprocess!
    end
  end
end
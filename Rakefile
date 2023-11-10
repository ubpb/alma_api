require "rake/testtask"
require "bundler/gem_tasks"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
  t.warning = false
end

task default: :test

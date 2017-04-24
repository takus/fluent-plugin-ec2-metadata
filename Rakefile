require "bundler/gem_tasks"
require "fluent/version"
require "rake/testtask"

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'

  test.test_files = case
    when Fluent::VERSION.start_with?("0.10.")
      ["test/plugin/test_out_ec2_metadata.rb"]
    else
      Dir['test/**/test_*.rb']
  end

  test.verbose = true
end

task default: :test

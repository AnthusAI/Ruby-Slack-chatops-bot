# frozen_string_literal: true

task :watch_specs do
  exec 'bundle exec guard'
end

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = '**/*.spec'
  t.rspec_opts = '--format documentation'
  t.verbose = true
end

task default: %i[spec]

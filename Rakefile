# frozen_string_literal: true
require "rake/testtask"
require "rubocop/rake_task"
require "bundler/gem_tasks"

task default: [:test, :rubocop]

Rake::TestTask.new do |t|
  t.libs << "test"
  t.warning = false
end

RuboCop::RakeTask.new

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = ['github/spec/**/*_spec.rb']
  end

  task default: :spec
rescue LoadError
  # no rspec available
end

load "github/tasks.rake"

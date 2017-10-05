begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = ['github/*_spec.rb']
  end

  task default: :spec
rescue LoadError
  # no rspec available
end

Dir.glob('github/tasks.rake').each { |r| load r}

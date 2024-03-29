require_relative "lib/configure_repos"
require_relative "lib/validate_repos"

namespace :github do
  desc "Configure the repos with correct settings and branch protection"
  task :configure_repos do
    ConfigureRepos.new.configure!
  end

  desc "List repos that the task will configure"
  task :list_repos do
    ConfigureRepos.new.list_repos
  end

  desc "Remove old webhooks"
  task :remove_old_webhooks do
    ConfigureRepos.new.remove_old_webhooks!
  end

  desc "Verify that GOVUK repos are tagged #govuk"
  task :verify_repo_tags do
    validator = ValidateRepos.new

    untagged_message = <<~UNTAGGED
      The following repos in the repos.yml file in govuk-developer-docs do not have the govuk tag on GitHub:
    UNTAGGED

    falsely_tagged_message = <<~FALSETAG
      The following repos have the govuk tag on GitHub but are not in the repos.yml file in govuk-developer-docs:
    FALSETAG

    puts "#{untagged_message}\n#{validator.untagged_repos}" unless validator.untagged_repos.empty?
    puts "#{falsely_tagged_message}\n#{validator.falsely_tagged_repos}" unless validator.falsely_tagged_repos.empty?

    exit 1 unless validator.untagged_repos.empty? && validator.falsely_tagged_repos.empty?
  end
end

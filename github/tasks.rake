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
    ValidateRepos.new.verify_repo_tags
  end
end

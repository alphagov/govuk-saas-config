require_relative 'lib/configure_repos'

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
    HOOKS_TO_DELETE = %w[
      https://ci.blue.integration.govuk.digital/github-webhook/
    ]

    repos.map do |repo|
      client.hooks(repo).each do |hook|
        next unless HOOKS_TO_DELETE.include?(hook.config.url)
        client.remove_hook(repo, hook.id)
      end
    end
  end
end

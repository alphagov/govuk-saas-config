require "yaml"
require "json"
require "octokit"
require_relative "./configure_repo"

class ConfigureRepos
  HOOKS_TO_DELETE = %w[
    https://ci.blue.integration.govuk.digital/github-webhook/
  ]


  def configure!
    repos.each do |repo|
      ConfigureRepo.new(repo, client, repo_overrides[repo[:full_name]]).configure!
    end
  end

  def list_repos
    puts repos.to_yaml
  end

  def remove_old_webhooks!

    repos.map do |repo|
      begin
      client.hooks(repo[:full_name]).each do |hook|
        next unless HOOKS_TO_DELETE.include?(hook.config.url)
          client.remove_hook(repo[:full_name], hook.id)
        end
      end
      rescue => e
        puts e.message
        puts e.inspect
      end
  end

private

  def repos
    client
      .org_repos("alphagov", accept: "application/vnd.github.mercy-preview+json")
      .select { |repo| repo.topics.to_a.include?("govuk") }
      .reject { |repo| ignored_repos.include?(repo.full_name) }
      .reject { |repo| repo.archived }
      .sort_by { |repo| repo[:full_name] }
  end

  def ignored_repos
    @ignored_repos ||= YAML.load_file("#{__dir__}/../ignored_repos.yml")
  end

  def repo_overrides
    @repo_overrides ||= YAML.load_file("#{__dir__}/../repo_overrides.yml")
  end

  def client
    Octokit.auto_paginate = true
    @client ||= Octokit::Client.new(access_token: ENV.fetch("GITHUB_TOKEN"))
  end
end

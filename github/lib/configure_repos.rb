require "yaml"
require "octokit"
require_relative "./configure_repo"
require_relative "./fetch_repos"

class ConfigureRepos
  HOOKS_TO_DELETE = %w[
    https://ci.blue.integration.govuk.digital/github-webhook/
  ]


  def configure!
    fetch_repos.each do |repo|
      ConfigureRepo.new(repo, client, repo_overrides[repo[:full_name]]).configure!
    end
  end

  def list_repos
    puts fetch_repos.to_yaml
  end

  def remove_old_webhooks!
    fetch_repos.map do |repo|
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

  def fetch_repos
    @fetch_repos ||= FetchRepos.new(client).repos
  end

  def repo_overrides
    @repo_overrides ||= YAML.load_file("#{__dir__}/../repo_overrides.yml")["repos"]
  end

  def client
    Octokit.auto_paginate = true
    @client ||= Octokit::Client.new(access_token: ENV.fetch("GITHUB_TOKEN"))
  end
end

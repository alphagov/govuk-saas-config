require "yaml"
require "json"
require "octokit"
require_relative "./configure_repo"

class ConfigureRepos
  def configure!
    repos.each do |repo|
      ConfigureRepo.new(repo, client, repo_overrides[repo]).configure!
    end
  end

  def list_repos
    puts repos.to_yaml
  end

private

  def repos
    client
      .org_repos("alphagov", accept: "application/vnd.github.mercy-preview+json")
      .select { |repo| repo.topics.to_a.include?("govuk") }
      .reject { |repo| ignored_repos.include?(repo.full_name) }
      .reject { |repo| repo.archived }
      .map(&:full_name)
      .sort
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

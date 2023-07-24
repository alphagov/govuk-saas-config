require "json"
require "octokit"
require "open-uri"
require_relative "./fetch_repos"

class ValidateRepos
  def initialize(client = nil)
    Octokit.auto_paginate = true
    @client = client || Octokit::Client.new(access_token: ENV.fetch("GITHUB_TOKEN"))
  end
  
  def github_repos_tagged_govuk
    FetchRepos.new(@client).repos
  end

  def verify_repo_tags
    govuk_repo_names = JSON.load(URI.open("https://docs.publishing.service.gov.uk/repos.json")).map { |repo| repo["app_name"] }
    github_repo_names = github_repos_tagged_govuk.map { |repo| repo["name"] }
      
    untagged_repos = (govuk_repo_names - github_repo_names).join("\n")
    falsely_tagged_repos = (github_repo_names - govuk_repo_names).join("\n")
  
    puts "Untagged govuk repos:\n#{untagged_repos}" unless untagged_repos.empty?
    puts "Falsely tagged govuk repos:\n#{falsely_tagged_repos}" unless falsely_tagged_repos.empty?

    exit 1 unless untagged_repos.empty? && falsely_tagged_repos.empty?
  end
end

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
    @github_repos_tagged_govuk ||= FetchRepos.new(@client).repos.map { |repo| repo["name"] }
  end

  def govuk_repo_names
    @govuk_repo_names ||= JSON.load(URI.open("https://docs.publishing.service.gov.uk/repos.json")).map { |repo| repo["app_name"] }
  end

  def untagged_repos
    (govuk_repo_names - github_repos_tagged_govuk).join("\n")
  end

  def falsely_tagged_repos
    (github_repos_tagged_govuk - govuk_repo_names).join("\n")
  end
end

require "yaml"
require "json"
require "octokit"
require "open-uri"
require "colorize"
require_relative "./configure_repo"
require_relative "./fetch_repos"

class ValidateRepos
  attr_reader :client
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
    
    untagged_govuk_repo_names = govuk_repo_names - github_repo_names
    falsely_tagged_govuk_repo_names = github_repo_names - govuk_repo_names
    
    if untagged_govuk_repo_names == []
      puts "Untagged govuk repos: No mismatches found.".colorize(:color => :green, :background => :black)
    
    else
      puts "Untagged govuk repos:".colorize(:color => :red, :background => :black)
      untagged_govuk_repo_names.each do |untag|
        puts untag
      end
    end  

    puts "\n"

    if falsely_tagged_govuk_repo_names == []
      puts "Falsely tagged govuk repos: No mismatches found.".colorize(:color => :green, :background => :black)
    
    else
      puts "Falsely tagged govuk repos:".colorize(:color => :red, :background => :black)
      falsely_tagged_govuk_repo_names.each do |falsetag|
        puts falsetag
      end
    end
  end
end

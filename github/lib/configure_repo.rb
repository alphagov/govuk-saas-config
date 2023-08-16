require "base64"
require "yaml"

class ConfigureRepo
  attr_reader :repo, :client

  def initialize(repo, client, overrides = nil)
    @repo = repo
    @client = client
    @overrides = overrides || {}
  end

  def configure!
    puts "Updating #{repo[:full_name]}"
    update_repo_settings
    protect_default_branch
    protect_gh_pages_branch
    update_webhooks
    enable_vulnerability_alerts
    enable_automated_security_fixes
    puts "√ #{repo[:full_name]}"
  rescue Octokit::NotFound => e
    puts "Could not find #{repo[:full_name]}. Possibly the govuk-ci user doesn't have admin access to this repo."
  end

private

  attr_reader :overrides

  def update_repo_settings
    client.edit_repository(
      repo[:full_name],
      allow_merge_commit: true,
      allow_squash_merge: overrides.fetch("allow_squash_merge", false),
      allow_rebase_merge: false,
      delete_branch_on_merge: true,
    )
  end

  def protect_default_branch
    config = {
      enforce_admins: true,
      required_status_checks: required_status_checks,
      required_pull_request_reviews: {
        dismiss_stale_reviews: false,
      }
    }

    if overrides["need_production_access_to_merge"]
      config.merge!(
        restrictions: { users: [], teams: %w[gov-uk-production-admin gov-uk-production-deploy] }
      )
    end

    client.protect_branch(repo[:full_name], repo[:default_branch], config)
  end

  def protect_gh_pages_branch
    # https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#update-branch-protection
    config = {
      enforce_admins: nil,
      required_status_checks: nil,
      required_pull_request_reviews: nil,
    }
    client.protect_branch(repo[:full_name], "gh-pages", config)
  rescue Octokit::NotFound => e
    # no gh-pages branch exists. Continue.
  end

  def update_webhooks
    existing_webhooks = client.hooks(repo[:full_name])

    # GitHub Trello Poster
    if existing_webhooks.map(&:config).map(&:url).include?("https://govuk-github-trello-poster.herokuapp.com/payload")
      puts "√ GitHub Trello Poster webhook exists"
    else
      puts "Creating GitHub Trello Poster webhook"
      client.create_hook(
        repo[:full_name],
        "web",
        {
          url: "https://govuk-github-trello-poster.herokuapp.com/payload",
          content_type: "json",
        },
        {
          events: ["pull_request"],
          active: true,
        }
      )
    end

    # Jenkins CI
    if jenkinsfile_exists?
      if existing_webhooks.map(&:config).map(&:url).include?("https://ci.integration.publishing.service.gov.uk/github-webhook/")
        puts "√ Jenkins CI webhook exists"
      else
        puts "Creating Jenkins CI webhook"
        client.create_hook(
          repo[:full_name],
          "web",
          {
            url: "https://ci.integration.publishing.service.gov.uk/github-webhook/",
            content_type: "json",
          },
          {
            events: ["push"],
            active: true,
          }
        )
      end
    end
  end

  def required_status_checks
    return nil unless jenkinsfile_exists? || !github_actions_test_job_name.nil?

    enforce_jenkins_checks = jenkinsfile_exists? && !overrides.dig("required_status_checks", "ignore_jenkins")

    {
      strict: overrides.fetch("up_to_date_branches", false),
      contexts: [
        enforce_jenkins_checks ? "continuous-integration/jenkins/branch" : nil,
        github_actions_test_job_name,
        *overrides
          .fetch("required_status_checks", {})
          .fetch("additional_contexts", [])
      ].compact
    }
  end

  def jenkinsfile
    @jenkinsfile ||= begin
      client.contents(repo[:full_name], path: "Jenkinsfile")
    rescue Octokit::NotFound
      nil
    end
  end

  def jenkinsfile_exists?
    !jenkinsfile.nil?
  end

  def jenkinsfile_content
    return nil unless jenkinsfile_exists?
    raise "Unknown encoding" unless jenkinsfile.encoding == "base64"
    Base64.decode64(jenkinsfile.content)
  end

  def github_actions
    @github_actions ||= begin
      encoded_content = client.contents(repo[:full_name], path: ".github/workflows/ci.yml").content
      decoded_content = Base64.decode64(encoded_content)
      YAML.load(decoded_content)
    rescue Octokit::NotFound
      nil
    end
  end

  def github_actions_test_job_name
    test_job = github_actions&.dig("jobs", "test")
    unless test_job.nil?
      test_job.fetch("name", "test")
    end
  end
  
  def enable_vulnerability_alerts
    client.enable_vulnerability_alerts(repo[:full_name])
  end

  def enable_automated_security_fixes
    client.put("https://api.github.com/repos/#{repo[:full_name]}/automated-security-fixes", accept: "application/vnd.github+json")
  end
end

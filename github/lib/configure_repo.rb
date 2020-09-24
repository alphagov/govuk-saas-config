require 'base64'
require 'yaml'

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
    protect_branch
    update_webhooks
    puts "√ #{repo[:full_name]}"
  rescue Octokit::NotFound => e
    puts "Could not find #{repo[:full_name]}. Possibly the govuk-ci user doesn't have admin access to this repo[:full_name]."
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

  def protect_branch
    config = {
      enforce_admins: true,
      required_status_checks: required_status_checks,
      required_pull_request_reviews: {
        dismiss_stale_reviews: false,
      }
    }

    if overrides["need_production_access_to_merge"]
      config.merge!(
        restrictions: { users: [], teams: %w[gov-uk-production] }
      )
    end

    client.protect_branch(repo[:full_name], repo[:default_branch], config)
  end

  def update_webhooks
    existing_webhooks = client.hooks(repo[:full_name])

    # GitHub Trello Poster
    if existing_webhooks.map(&:config).map(&:url).include?("https://github-trello-poster.cloudapps.digital/payload")
      puts "√ GitHub Trello Poster webhook exists"
    else
      puts "Creating GitHub Trello Poster webhook"
      client.create_hook(
        repo[:full_name],
        "web",
        {
          url: "https://github-trello-poster.cloudapps.digital/payload",
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
    return nil unless jenkinsfile_exists? || github_actions_exists?

    {
      strict: overrides.fetch("up_to_date_branches", false),
      contexts: [
        jenkinsfile_exists? ? "continuous-integration/jenkins/branch" : nil,
        jenkinsfile_runs_e2e_tests? ? "continuous-integration/jenkins/publishing-e2e-tests" : nil,
        github_actions_test_exists? ? "test" : nil,
        github_actions_pre_commit_exists? ? "pre-commit" : nil,
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

  def jenkinsfile_runs_e2e_tests?
    return false unless jenkinsfile_exists?

    /publishingE2ETests\:\s*true/.match(jenkinsfile_content)
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

  def github_actions_exists?
    github_actions_test_exists? || github_actions_pre_commit_exists?
  end

  def github_actions_test_exists?
    !github_actions.nil? && github_actions.key?("jobs") && github_actions["jobs"].key?("test")
  end

  def github_actions_pre_commit_exists?
    !github_actions.nil? && github_actions.key?("jobs") && github_actions["jobs"].key?("pre-commit")
  end
end

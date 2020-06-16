class ConfigureRepo
  attr_reader :repo, :client

  def initialize(repo, client, overrides = nil)
    @repo = repo
    @client = client
    @overrides = overrides || {}
  end

  def configure!
    puts "Updating #{repo}"
    update_repo_settings
    protect_branch
    update_webhooks
    puts "√ #{repo}"
  rescue Octokit::NotFound => e
    puts "Could not find #{repo}. Possibly the govuk-ci user doesn't have admin access to this repo."
  end

private

  attr_reader :overrides

  def update_repo_settings
    client.edit_repository(
      repo,
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

    client.protect_branch(repo, "master", config)
  end

  def update_webhooks
    existing_webhooks = client.hooks(repo)

    # GitHub Trello Poster
    if existing_webhooks.map(&:config).map(&:url).include?("https://github-trello-poster.cloudapps.digital/payload")
      puts "√ GitHub Trello Poster webhook exists"
    else
      puts "Creating GitHub Trello Poster webhook"
      client.create_hook(
        repo,
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
          repo,
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
        github_actions_exists? ? "test" : nil,
        *overrides
          .fetch("required_status_checks", {})
          .fetch("additional_contexts", [])
      ].compact
    }
  end

  def jenkinsfile
    @jenkinsfile ||= begin
      client.contents(repo, path: "Jenkinsfile")
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
      client.contents(repo, path: ".github/workflows/ci.yml")
    rescue Octokit::NotFound
      nil
    end
  end

  def github_actions_exists?
    !github_actions.nil?
  end
end

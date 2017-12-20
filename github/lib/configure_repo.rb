class ConfigureRepo
  attr_reader :repo, :client

  def initialize(repo, client)
    @repo = repo
    @client = client
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

  def update_repo_settings
    client.edit_repository(
      repo,
      allow_merge_commit: true,
      allow_squash_merge: false,
      allow_rebase_merge: false,
    )
  end

  def protect_branch
    client.protect_branch(
      repo,
      "master",
      {
        enforce_admins: true,
        required_status_checks: required_status_checks,
        required_pull_request_reviews: {
          dismiss_stale_reviews: false,
        }
      }
    )
  end

  def update_webhooks
    existing_webhooks = client.hooks(repo)

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
  end

  def required_status_checks
    if jenkinsfile_exists?
      {
        strict: false, # "Require branches to be up to date before merging"
        contexts: [
          "continuous-integration/jenkins/branch",
          jenkinsfile_runs_e2e_tests? ? "continuous-integration/jenkins/publishing-e2e-tests" : nil,
        ].compact
      }
    end
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
end

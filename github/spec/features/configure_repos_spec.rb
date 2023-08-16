require_relative '../spec_helper'
require_relative '../../lib/configure_repos'

require 'base64'
require 'yaml'

RSpec.describe ConfigureRepos do
  context "when a repo uses Jenkins for CI" do
    it "Updates a repo" do
      given_theres_a_repo
      and_the_repo_has_a_jenkinsfile
      and_the_repo_does_not_use_github_actions
      when_the_script_runs
      the_repo_is_updated_with_correct_settings
      the_repo_has_branch_protection_activated
      the_repo_has_gh_pages_branch_protection_activated
      the_repo_has_ci_enabled
      the_repo_has_webhooks_configured
      the_repo_has_vulnerability_alerts_enabled
      the_repo_has_automated_security_fixes_enabled
    end

    it "Updates an overridden repo" do
      given_theres_a_repo(full_name: "alphagov/smart-answers", allow_squash_merge: true, need_production_access_to_merge: true)
      and_the_repo_has_a_jenkinsfile(full_name: "alphagov/smart-answers")
      and_the_repo_does_not_use_github_actions(full_name: "alphagov/smart-answers")
      when_the_script_runs
      the_repo_is_updated_with_correct_settings
      the_repo_has_vulnerability_alerts_enabled
      the_repo_has_automated_security_fixes_enabled
    end

    it "Doesn't update a repo if it's archived" do
      given_theres_a_repo(archived: true)
      and_the_repo_has_a_jenkinsfile
      when_the_script_runs
      then_no_webhooks_are_changed
      the_repo_is_not_updated
    end
  end

  context "when a repo uses GitHub Actions for CI" do
    it "Updates a repo" do
      given_theres_a_repo(full_name: "alphagov/rubocop-govuk")
      and_the_repo_does_not_have_a_jenkinsfile(full_name: "alphagov/rubocop-govuk")
      and_the_repo_uses_github_actions_for_test(full_name: "alphagov/rubocop-govuk")
      when_the_script_runs
      the_repo_is_updated_with_correct_settings
      the_repo_has_branch_protection_activated
      the_repo_has_gh_pages_branch_protection_activated
      the_repo_has_ci_enabled(full_name: "alphagov/rubocop-govuk", providers: ["github_actions"])
      the_repo_has_webhooks_configured(number_of_webhooks: 1)
      the_repo_has_vulnerability_alerts_enabled
      the_repo_has_automated_security_fixes_enabled
    end

    it "Updates a squash merge overridden repo" do
      given_theres_a_repo(full_name: "alphagov/govuk-coronavirus-content", allow_squash_merge: true)
      and_the_repo_does_not_have_a_jenkinsfile(full_name: "alphagov/govuk-coronavirus-content")
      and_the_repo_uses_github_actions_for_test(full_name: "alphagov/govuk-coronavirus-content")
      when_the_script_runs
      the_repo_is_updated_with_correct_settings
      the_repo_has_vulnerability_alerts_enabled
      the_repo_has_automated_security_fixes_enabled
    end

    it "Updates a strict status checks overriden repo" do
      given_theres_a_repo(full_name: "alphagov/repo-for-govuk-saas-config-automated-tests")
      and_the_repo_does_not_have_a_jenkinsfile(full_name: "alphagov/repo-for-govuk-saas-config-automated-tests")
      and_the_repo_uses_github_actions_for_test(full_name: "alphagov/repo-for-govuk-saas-config-automated-tests")
      when_the_script_runs
      the_repo_has_ci_enabled(full_name: "alphagov/repo-for-govuk-saas-config-automated-tests", providers: ["github_actions"], up_to_date_branches: true)
      the_repo_has_branch_protection_activated
      the_repo_has_gh_pages_branch_protection_activated
      the_repo_is_updated_with_correct_settings
      the_repo_has_vulnerability_alerts_enabled
      the_repo_has_automated_security_fixes_enabled
    end

    context "and the test job has a custom name" do
      it "Uses the custom name" do
        given_theres_a_repo(full_name: "alphagov/rubocop-govuk")
        and_the_repo_does_not_have_a_jenkinsfile(full_name: "alphagov/rubocop-govuk")
        and_the_repo_uses_github_actions_for_test(full_name: "alphagov/rubocop-govuk", job_name: "Run tests")
        when_the_script_runs
        the_repo_has_ci_enabled(full_name: "alphagov/rubocop-govuk", providers: ["github_actions"], github_actions: ["Run tests"])
        the_repo_has_vulnerability_alerts_enabled
        the_repo_has_automated_security_fixes_enabled
      end
    end
  end

  context "when there are no supported CI provider config files" do
    it "doesn't set up CI if there is no Jenkinsfile or GitHub Actions config" do
      given_theres_a_repo
      and_the_repo_does_not_have_a_jenkinsfile
      and_the_repo_does_not_use_github_actions
      when_the_script_runs
      the_repo_is_updated_with_correct_settings
      the_repo_has_branch_protection_activated
      the_repo_has_gh_pages_branch_protection_activated
      the_repo_has_ci_disabled
      the_repo_has_webhooks_configured(number_of_webhooks: 1)
      the_repo_has_vulnerability_alerts_enabled
      the_repo_has_automated_security_fixes_enabled
    end
  end

  context "when a repo uses both Jenkins and GitHub Actions for CI" do
    it "sets up CI for both providers" do
      given_theres_a_repo(full_name: "alphagov/example")
      and_the_repo_has_a_jenkinsfile(full_name: "alphagov/example")
      and_the_repo_uses_github_actions_for_test(full_name: "alphagov/example")
      when_the_script_runs
      the_repo_has_ci_enabled(full_name: "alphagov/example", providers: ["jenkins", "github_actions"])
      the_repo_has_branch_protection_activated
      the_repo_has_gh_pages_branch_protection_activated
      the_repo_is_updated_with_correct_settings
      the_repo_has_vulnerability_alerts_enabled
      the_repo_has_automated_security_fixes_enabled
    end
  end

  describe "webhooks" do
    it "Only creates a webhook when missing" do
      given_theres_a_repo
      and_the_repo_already_has_webhooks
      then_no_webhooks_are_changed
    end
  end

  describe "branch protection" do
    it "Avoids adding branch protection to gh-pages branch unless it exists" do
      given_theres_a_repo
      and_the_repo_does_not_have_a_jenkinsfile
      and_the_repo_does_not_use_github_actions
      and_the_repo_has_no_gh_pages_branch
      when_the_script_runs
      no_exception_is_raised_to_stop_the_configuration
    end
  end

  def given_theres_a_repo(archived: false,
                          full_name: "alphagov/smart-sandwich",
                          allow_squash_merge: false,
                          need_production_access_to_merge: false,
                          default_branch: "main")
    stub_request(:get, "https://api.github.com/orgs/alphagov/repos?per_page=100").
      to_return(headers: { content_type: 'application/json' }, body: [ { full_name: full_name, archived: archived, topics: ["govuk"], default_branch: default_branch }, { full_name: 'alphagov/ignored-for-test', topics: ["govuk"] } ].to_json)

    stub_request(:get, "https://api.github.com/repos/#{full_name}/hooks?per_page=100").
      to_return(body: [].to_json, headers: { content_type: 'application/json' })

    @repo_update = stub_request(:patch, "https://api.github.com/repos/#{full_name}")
      .with(body: {
              allow_merge_commit: true,
              allow_squash_merge: allow_squash_merge,
              allow_rebase_merge: false,
              delete_branch_on_merge: true,
              name: full_name.split('/').last,
            })
      .to_return(body: {}.to_json, status: archived ? 403 : 200)

    @branch_protection_update = stub_request(:put, "https://api.github.com/repos/#{full_name}/branches/#{default_branch}/protection")
      .with(body: { enforce_admins: true,
              required_status_checks: hash_including({}),
              required_pull_request_reviews: {
                dismiss_stale_reviews: false,
              },
              restrictions: need_production_access_to_merge ?
               { users: [], teams: %w[gov-uk-production-admin gov-uk-production-deploy] } : nil,
            })
      .to_return(body: {}.to_json, status: archived ? 403 : 200)

    @gh_pages_branch_protection_update = stub_request(:put, "https://api.github.com/repos/#{full_name}/branches/gh-pages/protection")
      .to_return(body: {}.to_json, status: archived ? 403 : 200)

    @hook_creation = stub_request(:post, "https://api.github.com/repos/#{full_name}/hooks")
      .to_return(body: {}.to_json, status: archived ? 403 : 200)

    @vulnerability_alerts_enabled = stub_request(:put, "https://api.github.com/repos/#{full_name}/vulnerability-alerts")
      .to_return(body: {}.to_json, status: archived ? 403 : 204)

    @automated_security_fixes_enabled = stub_request(:put, "https://api.github.com/repos/#{full_name}/automated-security-fixes")
      .with(
        body: "{}",
        headers: {
        'Accept'=>'application/vnd.github+json',
        'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization'=>'token A_FAKE_TOKEN',
        'Content-Type'=>'application/json',
        'User-Agent'=>'Octokit Ruby Gem 6.0.1'
        })
      .to_return(status: archived ? 403 : 204, body: "", headers: {})
  end

  def and_the_repo_has_a_jenkinsfile(full_name: "alphagov/smart-sandwich")
    payload = {
      name: "Jenkinsfile",
      content: "",
      encoding: "base64",
    }

    stub_request(:get, "https://api.github.com/repos/#{full_name}/contents/Jenkinsfile").
      to_return(body: payload.to_json, headers: { content_type: "application/json" }, status: 200)
  end

  def and_the_repo_does_not_have_a_jenkinsfile(full_name: "alphagov/smart-sandwich")
    stub_request(:get, "https://api.github.com/repos/#{full_name}/contents/Jenkinsfile").
      to_return(status: 404)
  end

  def and_the_repo_uses_github_actions_for_test(full_name: "alphagov/govuk-coronavirus-content", job_name: nil)
    content = {
      "on" => %w[push pull_request],
      "jobs" => {
        "test" => job_name.nil? ? {} : {"name" => job_name},
      }
    }

    payload = {
      content: Base64.encode64(content.to_yaml)
    }

    stub_request(:get, "https://api.github.com/repos/#{full_name}/contents/.github/workflows/ci.yml").
      to_return(body: payload.to_json, headers: { content_type: "application/json" }, status: 200)
  end

  def and_the_repo_does_not_use_github_actions(full_name: "alphagov/smart-sandwich")
    stub_request(:get, "https://api.github.com/repos/#{full_name}/contents/.github/workflows/ci.yml").
      to_return(status: 404)
  end

  def and_the_repo_already_has_webhooks
    payload = [
      { config: { url: "https://govuk-github-trello-poster.herokuapp.com/payload" }},
      { config: { url: "https://ci.integration.publishing.service.gov.uk/github-webhook/" }}
    ]

    stub_request(:get, "https://api.github.com/repos/alphagov/smart-sandwich/hooks?per_page=100").
      to_return(body: payload.to_json, headers: { content_type: 'application/json' })
  end

  def and_the_repo_has_no_gh_pages_branch
    @gh_pages_branch_protection_update = stub_request(:put, "https://api.github.com/repos/alphagov/smart-sandwich/branches/gh-pages/protection")
      .to_return(body: {}.to_json, status: 404)
  end

  def no_exception_is_raised_to_stop_the_configuration
    # `enable_automated_security_fixes` is the last step of the configuration.
    # If it has succeeded, then we know the `Octokit::NotFound` exception raised
    # by any earlier steps did not prevent the later steps from being actioned.
    the_repo_has_automated_security_fixes_enabled
  end

  def when_the_script_runs
    ConfigureRepos.new.configure!
  end

  def the_repo_is_not_updated
    expect(@repo_update).not_to have_been_requested
    expect(@branch_protection_update).not_to have_been_requested
  end

  def the_repo_is_updated_with_correct_settings(allow_squash_merge: false)
    expect(@repo_update).to have_been_requested
  end

  def the_repo_has_branch_protection_activated
    expect(@branch_protection_update).to have_been_requested
  end

  def the_repo_has_gh_pages_branch_protection_activated
    expect(@gh_pages_branch_protection_update).to have_been_requested
  end

  def the_repo_has_ci_enabled(full_name: "alphagov/smart-sandwich", providers: ["jenkins"], up_to_date_branches: false, default_branch: "main", github_actions: "test")
    payload = {
      required_status_checks: {
        strict: up_to_date_branches,
        contexts: [
          providers.include?("jenkins") ? "continuous-integration/jenkins/branch" : nil,
          providers.include?("github_actions") ? github_actions : nil,
        ].compact.flatten
      }
    }

    expect(WebMock).to have_requested(:put, "https://api.github.com/repos/#{full_name}/branches/#{default_branch}/protection").
      with(body: hash_including(payload))
  end

  def the_repo_has_ci_disabled(full_name: "alphagov/smart-sandwich", default_branch: "main")
    payload = {
      required_status_checks: nil
    }

    expect(WebMock).to have_requested(:put, "https://api.github.com/repos/#{full_name}/branches/#{default_branch}/protection").
      with(body: hash_including(payload))
  end

  def the_repo_has_webhooks_configured(number_of_webhooks: 2)
    expect(@hook_creation).to have_been_requested.times(number_of_webhooks)
  end

  def then_no_webhooks_are_changed
    expect(@hook_creation).not_to have_been_requested
  end

  def the_repo_has_vulnerability_alerts_enabled
    expect(@vulnerability_alerts_enabled).to have_been_requested
  end

  def the_repo_has_automated_security_fixes_enabled
    expect(@automated_security_fixes_enabled).to have_been_requested
  end
end

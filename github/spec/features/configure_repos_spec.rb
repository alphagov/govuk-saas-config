require_relative '../spec_helper'
require_relative '../../lib/configure_repos'

RSpec.describe ConfigureRepos do
  context "when a repo uses Jenkins for CI" do
    it "Updates a repo" do
      given_theres_a_repo
      and_the_repo_has_a_jenkinsfile
      when_the_script_runs
      the_repo_is_updated_with_correct_settings
      the_repo_has_branch_protection_activated
      the_repo_has_ci_enabled
      the_repo_has_webhooks_configured
    end

    it "Updates an overridden repo" do
      given_theres_a_repo(full_name: "alphagov/smartanswers", allow_squash_merge: true)
      and_the_repo_has_a_jenkinsfile(full_name: "alphagov/smartanswers")
      when_the_script_runs
      the_repo_is_updated_with_correct_settings
    end

    it "Doesn't update a repo if it's archived" do
      given_theres_a_repo(archived: true)
      and_the_repo_has_a_jenkinsfile
      when_the_script_runs
      then_no_webhooks_are_changed
      the_repo_is_not_updated
    end

    it "Updates a repo with e2e tests" do
      given_theres_a_repo
      and_the_repo_has_a_jenkinsfile(with_e2e_tests: true)
      when_the_script_runs
      the_repo_is_updated_with_correct_settings
      the_repo_has_branch_protection_activated
      the_repo_has_ci_enabled(with_e2e_tests: true)
      the_repo_has_webhooks_configured
    end
  end

  context "when a repo uses GitHub Actions for CI" do
    it "Updates a repo" do
      given_theres_a_repo(full_name: "alphagov/rubocop-govuk")
      and_the_repo_does_not_have_a_jenkinsfile(full_name: "alphagov/rubocop-govuk")
      and_the_repo_uses_github_actions(full_name: "alphagov/rubocop-govuk")
      when_the_script_runs
      the_repo_is_updated_with_correct_settings
      the_repo_has_branch_protection_activated
      the_repo_has_ci_enabled(full_name: "alphagov/rubocop-govuk", provider: "github_actions")
      the_repo_has_webhooks_configured(number_of_webhooks: 1)
    end

    it "Updates a squash merge overridden repo" do
      given_theres_a_repo(full_name: "alphagov/govuk-coronavirus-content", allow_squash_merge: true)
      and_the_repo_does_not_have_a_jenkinsfile(full_name: "alphagov/govuk-coronavirus-content")
      and_the_repo_uses_github_actions(full_name: "alphagov/govuk-coronavirus-content")
      when_the_script_runs
      the_repo_is_updated_with_correct_settings
    end

    it "Updates a strict status checks overriden repo" do
      given_theres_a_repo(full_name: "alphagov/govuk-coronavirus-vulnerable-people-form")
      and_the_repo_does_not_have_a_jenkinsfile(full_name: "alphagov/govuk-coronavirus-vulnerable-people-form")
      and_the_repo_uses_github_actions(full_name: "alphagov/govuk-coronavirus-vulnerable-people-form")
      when_the_script_runs
      the_repo_has_ci_enabled(full_name: "alphagov/govuk-coronavirus-vulnerable-people-form", provider: "github_actions", up_to_date_branches: true)
      the_repo_has_branch_protection_activated
      the_repo_is_updated_with_correct_settings
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
      the_repo_has_ci_disabled
      the_repo_has_webhooks_configured(number_of_webhooks: 1)
    end
  end


  describe "webhooks" do
    it "Only creates a webhook when missing" do
      given_theres_a_repo
      and_the_repo_already_has_webhooks
      then_no_webhooks_are_changed
    end
  end

  def given_theres_a_repo(archived: false, full_name: "alphagov/publishing-api", allow_squash_merge: false)
    stub_request(:get, "https://api.github.com/orgs/alphagov/repos?per_page=100").
      to_return(headers: { content_type: 'application/json' }, body: [ { full_name: full_name, archived: archived, topics: ["govuk"] }, { full_name: 'alphagov/ignored-for-test', topics: ["govuk"] } ].to_json)

    stub_request(:get, "https://api.github.com/repos/#{full_name}/hooks?per_page=100").
      to_return(body: [].to_json, headers: { content_type: 'application/json' })

    @repo_update = stub_request(:patch, "https://api.github.com/repos/#{full_name}")
      .with(
        body: {
          allow_merge_commit: true,
          allow_squash_merge: allow_squash_merge,
          allow_rebase_merge: false,
          delete_branch_on_merge: true,
          name: full_name.split('/').last,
        }.to_json
      )
      .to_return(body: {}.to_json, status: archived ? 403 : 200)

    @branch_protection_update = stub_request(:put, "https://api.github.com/repos/#{full_name}/branches/master/protection").to_return(body: {}.to_json, status: archived ? 403 : 200)
    @hook_creation = stub_request(:post, "https://api.github.com/repos/#{full_name}/hooks").to_return(body: {}.to_json, status: archived ? 403 : 200)
  end

  def and_the_repo_has_a_jenkinsfile(with_e2e_tests: false, full_name: "alphagov/publishing-api")
    payload = {
      name: "Jenkinsfile",
      content: Base64.encode64(with_e2e_tests ? "node { govuk.buildProject(publishingE2ETests: true) }" : ""),
      encoding: "base64",
    }

    stub_request(:get, "https://api.github.com/repos/#{full_name}/contents/Jenkinsfile").
      to_return(body: payload.to_json, headers: { content_type: "application/json" }, status: 200)
  end

  def and_the_repo_does_not_have_a_jenkinsfile(full_name: "alphagov/publishing-api")
    stub_request(:get, "https://api.github.com/repos/#{full_name}/contents/Jenkinsfile").
      to_return(status: 404)
  end

  def and_the_repo_uses_github_actions(full_name: "alphagov/govuk-coronavirus-content")
    payload = {
      path: ".github/workflows/ci.yml",
    }

    stub_request(:get, "https://api.github.com/repos/#{full_name}/contents/.github/workflows/ci.yml").
      to_return(body: payload.to_json, headers: { content_type: "application/json" }, status: 200)
  end

  def and_the_repo_does_not_use_github_actions
    stub_request(:get, "https://api.github.com/repos/alphagov/publishing-api/contents/.github/workflows/ci.yml").
      to_return(status: 404)
  end

  def and_the_repo_already_has_webhooks
    payload = [
      { config: { url: "https://github-trello-poster.cloudapps.digital/payload" }},
      { config: { url: "https://ci.integration.publishing.service.gov.uk/github-webhook/" }}
    ]

    stub_request(:get, "https://api.github.com/repos/alphagov/publishing-api/hooks?per_page=100").
      to_return(body: payload.to_json, headers: { content_type: 'application/json' })
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

  def the_repo_has_ci_enabled(full_name: "alphagov/publishing-api", provider: "jenkins", with_e2e_tests: false, up_to_date_branches: false)
    payload = {
      required_status_checks: {
        strict: up_to_date_branches,
        contexts: [
          provider == "jenkins" ? "continuous-integration/jenkins/branch" : nil,
          provider == "github_actions" ? "test" : nil,
          with_e2e_tests ? "continuous-integration/jenkins/publishing-e2e-tests" : nil,
        ].compact
      }
    }

    expect(WebMock).to have_requested(:put, "https://api.github.com/repos/#{full_name}/branches/master/protection").
      with(body: hash_including(payload))
  end

  def the_repo_has_ci_disabled(full_name: "alphagov/publishing-api")
    payload = {
      required_status_checks: nil
    }

    expect(WebMock).to have_requested(:put, "https://api.github.com/repos/#{full_name}/branches/master/protection").
      with(body: hash_including(payload))
  end

  def the_repo_has_webhooks_configured(number_of_webhooks: 2)
    expect(@hook_creation).to have_been_requested.times(number_of_webhooks)
  end

  def then_no_webhooks_are_changed
    expect(@hook_creation).not_to have_been_requested
  end
end

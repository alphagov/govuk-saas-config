require_relative '../spec_helper'
require_relative '../../lib/configure_repos'

RSpec.describe ConfigureRepos do
  it "Updates a repo" do
    given_theres_a_repo
    and_the_repo_has_a_jenkinsfile
    when_the_script_runs
    the_repo_is_updated_with_correct_settings
    the_repo_has_branch_protection_activated
    the_repo_has_ci_enabled
    the_repo_has_webhooks_configured
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

  it "Doesn't set up CI if there is no Jenkinsfile" do
    given_theres_a_repo
    and_the_repo_does_not_have_a_jenkinsfile
    when_the_script_runs
    the_repo_is_updated_with_correct_settings
    the_repo_has_branch_protection_activated
    the_repo_has_ci_disabled
    the_repo_has_webhooks_configured(number_of_webhooks: 1)
  end

  it "Only creates a webhook when missing" do
    given_theres_a_repo
    and_the_repo_already_has_webhooks
    then_no_webhooks_are_changed
  end

  def given_theres_a_repo(archived: false)
    stub_request(:get, "https://api.github.com/orgs/alphagov/repos?per_page=100").
      to_return(headers: { content_type: 'application/json' }, body: [ { full_name: 'alphagov/publishing-api', archived: archived, topics: ["govuk"] }, { full_name: 'alphagov/ignored-for-test', topics: ["govuk"] } ].to_json)

    stub_request(:get, "https://api.github.com/repos/alphagov/publishing-api/hooks?per_page=100").
      to_return(body: [].to_json, headers: { content_type: 'application/json' })

    @repo_update = stub_request(:patch, "https://api.github.com/repos/alphagov/publishing-api").to_return(body: {}.to_json, status: archived ? 403 : 200)
    @branch_protection_update = stub_request(:put, "https://api.github.com/repos/alphagov/publishing-api/branches/master/protection").to_return(body: {}.to_json, status: archived ? 403 : 200)
    @hook_creation = stub_request(:post, "https://api.github.com/repos/alphagov/publishing-api/hooks").to_return(body: {}.to_json, status: archived ? 403 : 200)
  end

  def and_the_repo_has_a_jenkinsfile(with_e2e_tests: false)
    payload = {
      name: "Jenkinsfile",
      content: Base64.encode64(with_e2e_tests ? "node { govuk.buildProject(publishingE2ETests: true) }" : ""),
      encoding: "base64",
    }

    stub_request(:get, "https://api.github.com/repos/alphagov/publishing-api/contents/Jenkinsfile").
      to_return(body: payload.to_json, headers: { content_type: "application/json" }, status: 200)
  end

  def and_the_repo_does_not_have_a_jenkinsfile
    stub_request(:get, "https://api.github.com/repos/alphagov/publishing-api/contents/Jenkinsfile").
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

  def the_repo_is_updated_with_correct_settings
    expect(@repo_update).to have_been_requested
  end

  def the_repo_has_branch_protection_activated
    expect(@branch_protection_update).to have_been_requested
  end

  def the_repo_has_ci_enabled(with_e2e_tests: false)
    payload = {
      required_status_checks: {
        strict: false,
        contexts: [
          "continuous-integration/jenkins/branch",
          with_e2e_tests ? "continuous-integration/jenkins/publishing-e2e-tests" : nil,
        ].compact
      }
    }

    expect(WebMock).to have_requested(:put, "https://api.github.com/repos/alphagov/publishing-api/branches/master/protection").
      with(body: hash_including(payload))
  end

  def the_repo_has_ci_disabled
    payload = {
      required_status_checks: nil
    }

    expect(WebMock).to have_requested(:put, "https://api.github.com/repos/alphagov/publishing-api/branches/master/protection").
      with(body: hash_including(payload))
  end

  def the_repo_has_webhooks_configured(number_of_webhooks: 2)
    expect(@hook_creation).to have_been_requested.times(number_of_webhooks)
  end

  def then_no_webhooks_are_changed
    expect(@hook_creation).not_to have_been_requested
  end
end

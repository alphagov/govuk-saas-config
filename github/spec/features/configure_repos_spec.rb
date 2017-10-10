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

  it "Doesn't set up CI if there is no Jenkinsfile" do
    given_theres_a_repo
    and_the_repo_does_not_have_a_jenkinsfile
    when_the_script_runs
    the_repo_is_updated_with_correct_settings
    the_repo_has_branch_protection_activated
    the_repo_has_ci_disabled
    the_repo_has_webhooks_configured
  end

  it "Only creates a webhook when missing" do
    given_theres_a_repo
    and_the_repo_has_a_github_trello_webhook_already
    then_no_webhooks_are_changed
  end

  def given_theres_a_repo
    stub_request(:get, "https://api.github.com/orgs/alphagov/repos?per_page=100").
      to_return(headers: { content_type: 'application/json' }, body: [ { full_name: 'alphagov/publishing-api', topics: ["govuk"] }, { full_name: 'alphagov/ignored-for-test', topics: ["govuk"] } ].to_json)

    stub_request(:get, "https://api.github.com/repos/alphagov/publishing-api/hooks?per_page=100").
      to_return(body: [].to_json, headers: { content_type: 'application/json' })

    @repo_update = stub_request(:patch, "https://api.github.com/repos/alphagov/publishing-api").to_return(body: {}.to_json)
    @branch_protection_update = stub_request(:put, "https://api.github.com/repos/alphagov/publishing-api/branches/master/protection").to_return(body: {}.to_json)
    @hook_creation = stub_request(:post, "https://api.github.com/repos/alphagov/publishing-api/hooks").to_return(body: {}.to_json)
  end

  def and_the_repo_has_a_jenkinsfile
    stub_request(:get, "https://api.github.com/repos/alphagov/publishing-api/contents/Jenkinsfile").
      to_return(status: 200)
  end

  def and_the_repo_does_not_have_a_jenkinsfile
    stub_request(:get, "https://api.github.com/repos/alphagov/publishing-api/contents/Jenkinsfile").
      to_return(status: 404)
  end

  def and_the_repo_has_a_github_trello_webhook_already
    payload = [
      { config: { url: "https://github-trello-poster.cloudapps.digital/payload" }}
    ]

    stub_request(:get, "https://api.github.com/repos/alphagov/publishing-api/hooks?per_page=100").
      to_return(body: payload.to_json, headers: { content_type: 'application/json' })
  end

  def when_the_script_runs
    ConfigureRepos.new.configure!
  end

  def the_repo_is_updated_with_correct_settings
    expect(@repo_update).to have_been_requested
  end

  def the_repo_has_branch_protection_activated
    expect(@branch_protection_update).to have_been_requested
  end

  def the_repo_has_ci_enabled
    payload = {
      required_status_checks: {
        strict: false,
        contexts: ["continuous-integration/jenkins/branch"]
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

  def the_repo_has_webhooks_configured
    expect(@hook_creation).to have_been_requested
  end

  def then_no_webhooks_are_changed
    expect(@hook_creation).not_to have_been_requested
  end
end

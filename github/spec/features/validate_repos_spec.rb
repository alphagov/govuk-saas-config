require_relative "../spec_helper"
require_relative "../../lib/validate_repos"

RSpec.describe ValidateRepos do

  before do
    @repo_mock = double("Repo", topics: ["govuk"], archived: false)
    allow(@repo_mock).to receive(:[]).with("name").and_return("this-is-a-govuk-repo")
    allow(@repo_mock).to receive(:full_name).and_return("this-is-a-govuk-repo")
    allow(@repo_mock).to receive(:[]).with(:full_name).and_return("this-is-a-govuk-repo")
    @octokit_mock = double("Octokit::Client", org_repos: [@repo_mock])
  end

  it "should ignore any repos that exist in repos.json AND are tagged govuk in GitHub" do
    repos = [{
      "app_name": "this-is-a-govuk-repo",
    }]

    stub_repos_json(repos)

    validator = ValidateRepos.new(@octokit_mock)

    expect(validator.untagged_repos).to eq("")
    expect(validator.falsely_tagged_repos).to eq("")
  end

  it "should alert if finds an untagged repo in repos.json" do
    repos = [
      { "app_name": "this-is-a-govuk-repo", },
      { "app_name": "this-govuk-repo-is-not-tagged!", }
    ]

    stub_repos_json(repos)

    validator = ValidateRepos.new(@octokit_mock)

    expect(validator.untagged_repos).to eq("this-govuk-repo-is-not-tagged!")
    expect(validator.falsely_tagged_repos).to eq("")
  end

  it "should alert if it finds a repo that has falsely been tagged as govuk." do
    repos = []

    stub_repos_json(repos)

    validator = ValidateRepos.new(@octokit_mock)

    expect(validator.falsely_tagged_repos).to eq("this-is-a-govuk-repo")
    expect(validator.untagged_repos).to eq("")
  end

  def stub_repos_json(repos)
    stub_request(:get, "https://docs.publishing.service.gov.uk/repos.json").
      to_return(status: 200, body: repos.to_json, headers: {})
  end
end

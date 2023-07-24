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

    expect { ValidateRepos.new(@octokit_mock).verify_repo_tags }.to_not output.to_stdout
  end

  it "should alert if finds an untagged repo in repos.json" do
    repos = [
      { "app_name": "this-is-a-govuk-repo", },
      { "app_name": "this-govuk-repo-is-not-tagged!", }
    ]

    stub_repos_json(repos)

    expect { ValidateRepos.new(@octokit_mock).verify_repo_tags }.to output("Untagged govuk repos:\nthis-govuk-repo-is-not-tagged!\n").to_stdout.and raise_error(SystemExit)
  end

  it "should alert if it finds a repo that has falsely been tagged as govuk." do
    repos = []

    stub_repos_json(repos)

    expect { ValidateRepos.new(@octokit_mock).verify_repo_tags }.to output("Falsely tagged govuk repos:\nthis-is-a-govuk-repo\n").to_stdout.and raise_error(SystemExit)
  end

  it "should alert reports findings accordingly and appropriately when it finds both." do
    repos = [{
      "app_name": "this-govuk-repo-is-not-tagged!", 
    }]

    stub_repos_json(repos)

    expect { ValidateRepos.new(@octokit_mock).verify_repo_tags }.to output("Untagged govuk repos:\nthis-govuk-repo-is-not-tagged!\nFalsely tagged govuk repos:\nthis-is-a-govuk-repo\n").to_stdout.and raise_error(SystemExit)
  end

  def stub_repos_json(repos)
    stub_request(:get, "https://docs.publishing.service.gov.uk/repos.json").
      to_return(status: 200, body: repos.to_json, headers: {})
  end
end

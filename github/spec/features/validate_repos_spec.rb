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

    expect { ValidateRepos.new(@octokit_mock).verify_repo_tags }.to output("\e[0;32;40mUntagged govuk repos: No mismatches found.\e[0m\n\n\e[0;32;40mFalsely tagged govuk repos: No mismatches found.\e[0m\n").to_stdout
  end

  it "should alert if finds an untagged repo in repos.json" do
    repos = [
      { "app_name": "this-is-a-govuk-repo", },
      { "app_name": "this-govuk-repo-is-not-tagged!", }
    ]

    stub_repos_json(repos)

    expect { ValidateRepos.new(@octokit_mock).verify_repo_tags }.to output("\e[0;31;40mUntagged govuk repos:\e[0m\nthis-govuk-repo-is-not-tagged!\n\n\e[0;32;40mFalsely tagged govuk repos: No mismatches found.\e[0m\n").to_stdout
  end

  it "should alert if it finds a repo that has falsely been tagged as govuk." do
    repos = []

    stub_repos_json(repos)

    expect { ValidateRepos.new(@octokit_mock).verify_repo_tags }.to output("\e[0;32;40mUntagged govuk repos: No mismatches found.\e[0m\n\n\e[0;31;40mFalsely tagged govuk repos:\e[0m\nthis-is-a-govuk-repo\n").to_stdout
  end

  it "should alert reports findings accordingly and appropriately when it finds both." do
    repos = [{
      "app_name": "this-govuk-repo-is-not-tagged!", 
    }]

    stub_repos_json(repos)

    expect { ValidateRepos.new(@octokit_mock).verify_repo_tags }.to output("\e[0;31;40mUntagged govuk repos:\e[0m\nthis-govuk-repo-is-not-tagged!\n\n\e[0;31;40mFalsely tagged govuk repos:\e[0m\nthis-is-a-govuk-repo\n").to_stdout
  end

  def stub_repos_json(repos)
    stub_request(:get, "https://docs.publishing.service.gov.uk/repos.json").
      to_return(status: 200, body: repos.to_json, headers: {})
  end
end

require_relative "./spec_helper"
require_relative "../lib/configure_repo"

RSpec.describe ConfigureRepo do
  before do
    allow_any_instance_of(FetchRepos).to receive(:ignored_repos).and_return(["alphagov/ignored-for-test"])
  end

  describe "required_status_checks" do
    let(:repo) {  { full_name: "alphagov/foo" } }
    let(:client) { nil }

    it "should return no additional contexts if no overrides provided" do
      overrides = {}
      configured_repo = ConfigureRepo.new(repo, client, overrides)
      allow(configured_repo).to receive(:github_actions_test_job_name).and_return(nil)

      expect(configured_repo.required_status_checks).to eq({
        strict: false,
        contexts: [],
      })
    end

    it "should set `strict: true` if up_to_date_branches is set to `true`" do
      overrides = {
        "up_to_date_branches" => true,
      }
      configured_repo = ConfigureRepo.new(repo, client, overrides)
      allow(configured_repo).to receive(:github_actions_test_job_name).and_return(nil)

      expect(configured_repo.required_status_checks).to eq({
        strict: true,
        contexts: [],
      })
    end

    it "should return additional_contexts if provided" do
      overrides = {
        "required_status_checks" => {
          "additional_contexts" => [
            "bar",
            "baz",
          ]
        }
      }
      configured_repo = ConfigureRepo.new(repo, client, overrides)
      allow(configured_repo).to receive(:github_actions_test_job_name).and_return(nil)

      expect(configured_repo.required_status_checks).to eq({
        strict: false,
        contexts: [
          "bar",
          "baz",
        ],
      })
    end

    it "should include standard_contexts if provided" do
      overrides = {
        "required_status_checks" => {
          "standard_contexts" => [
            "foo",
          ],
          "additional_contexts" => [
            "bar",
          ],
        }
      }
      configured_repo = ConfigureRepo.new(repo, client, overrides)
      allow(configured_repo).to receive(:github_actions_test_job_name).and_return(nil)

      expect(configured_repo.required_status_checks).to eq({
        strict: false,
        contexts: [
          "foo",
          "bar",
        ],
      })
    end

    it "should include the GitHub Actions test job name if it exists" do
      overrides = {
        "required_status_checks" => {
          "additional_contexts" => [
            "bar",
            "baz",
          ]
        }
      }
      configured_repo = ConfigureRepo.new(repo, client, overrides)
      allow(configured_repo).to receive(:github_actions_test_job_name).and_return("test")

      expect(configured_repo.required_status_checks).to eq({
        strict: false,
        contexts: [
          "test",
          "bar",
          "baz",
        ],
      })
    end
  end
end

require "yaml"

class FetchRepos
  def initialize(client = nil)
    @client = client
  end

  def repos(with_ignored: false)
    # org_repos = @client
    # .org_repos("alphagov", accept: "application/vnd.github.mercy-preview+json")
    # puts ">>>> ORG repos"
    # puts org_repos

    @client
      .org_repos("alphagov", accept: "application/vnd.github.mercy-preview+json")
      .select { |repo| repo.topics.to_a.include?("govuk") } 
      .reject { |repo| repo.archived }
      .reject { |repo| !with_ignored && ignored_repos.include?(repo.full_name) }
      .sort_by { |repo| repo[:full_name] }
    # puts ">>>> FetchRepos.repos"
    # puts x
    # x
  end

  def ignored_repos
    @ignored_repos ||= YAML.load_file("#{__dir__}/../ignored_repos.yml")
  end
end

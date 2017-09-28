require 'sentry-api'
require 'http'
require 'yaml'

ORG_SLUG = 'govuk' # test account
DEFAULT_TEAM = 'govuk-all'

SentryApi.configure do |config|
  config.endpoint = 'https://sentry.io/api/0'
  config.auth_token = ENV.fetch('SENTRY_AUTH_TOKEN')
  config.default_org_slug = ORG_SLUG
end

def fetch_govuk_apps
  JSON.parse(HTTP.get("https://docs.publishing.service.gov.uk/apps.json").body)
end

def team_name(original_slack_name)
  if original_slack_name
    original_slack_name.gsub('#', '') + "-team"
  else
    DEFAULT_TEAM
  end
end

desc "Output the API keys for all apps as hiera"
task :api_keys do
  fetch_govuk_apps.each do |app|
    secret = SentryApi.client_keys("app-#{app["app_name"]}").first.dsn.secret

    puts "govuk::apps::#{app["puppet_name"]}::sentry_dsn: DEC::GPG[#{secret}]!"
  end
end

desc "Create all the teams"
task :create_teams do
  begin
    puts "Creating #{DEFAULT_TEAM}"
    SentryApi.create_team(name: "GOV.UK", slug: DEFAULT_TEAM)
  rescue => e
    puts e.message
    puts e.inspect
  end

  team_names = fetch_govuk_apps.map { |a| team_name(a["team"]) }.compact.uniq
  team_names.each do |team_name|
    begin
      puts "Creating #{team_name}"
      SentryApi.create_team(name: team_name, slug: team_name)
    rescue => e
      puts e.message
      puts e.inspect
    end
  end
end

desc "Create or update Sentry projects for all GOV.UK applications"
task :update_projects do
  apps = fetch_govuk_apps
  sentry_projects = SentryApi.organization_projects

  puts "There are #{sentry_projects.size} projects in Sentry"
  puts "There are #{apps.size} applications on GOV.UK"

  apps.map do |app|
    app_name = app.fetch("app_name")
    app_slug = "app-#{app_name}"

    project = sentry_projects.find { |project| project.slug == app_slug }

    if project
      puts "√ #{app_name} has a Sentry project (#{project.slug})"
    else
      team_name = team_name(app["team"])
      puts "Creating project #{app_name} (#{app_slug}) for team #{team_name}"
      project = SentryApi.create_project(team_name, name: app_name, slug: app_slug)
      puts "Created project for #{app_name} (#{project.slug})"
    end

    SentryApi.update_project(
      project.slug,
      platform: 'ruby',
      slug: app_slug,
      subjectTemplate: "[${project} @ ${tag:environment}] ${tag:level}: $title (${tag:release})",
    )
  end
end

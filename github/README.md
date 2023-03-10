# GOV.UK GitHub Config

Tools to make sure all of our repos have the same settings.

## Tasks

### `rake github:configure_repos`

Will update the relevant settings, webhooks and branch protections for all alphagov
repos tagged with the [topic govuk](https://github.com/search?q=topic%3Agovuk+org%3Aalphagov+fork%3Atrue).

Requires a GitHub personal access token, which can be generated using the [GitHub UI](https://github.com/settings/tokens).

Usage (can run on your Mac or within dev VM):

```
GITHUB_TOKEN=xyz bundle exec rake github:configure_repos
```

### `rake github:verify_repo_tags`

Will compare the list of currently GOVUK tagged repos on GitHub with the list of repos in devdocs (https://github.com/alphagov/govuk-developer-docs/blob/main/data/repos.yml), then prints a list of untagged and
falesly tagged repos.

Requires a GitHub personal access token, which can be generated using the [GitHub UI](https://github.com/settings/tokens/new), with full repo scope permissions, otherwise private repositories might
incorrectly show up as untagged.

Usage (can run on your Mac or within dev VM):

```
GITHUB_TOKEN=xyz bundle exec rake github:verify_repo_tags
```

## How changes get applied

There is a [jenkins job](https://github.com/alphagov/govuk-puppet/blob/02f4971ec60edf6592b02e2c29227aae534dfa4f/modules/govuk_jenkins/templates/jobs/configure_github_repos.yaml.erb) configured to run at ~8am every day, which automatically runs the above rake command and applies changes.

If you need a change applied sooner, you can either run the rake task or [manually run the jenkins job](https://deploy.blue.production.govuk.digital/job/configure-github-repos/).

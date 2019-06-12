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

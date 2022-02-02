# GOV.UK SaaS Config

Collection of scripts to configure Software as a Service applications we use.

## [Sentry](/sentry)

Tool to create and manage lots of applications in Sentry

## [GitHub](/github)

Tool to make sure all GOV.UK repos have the same settings and webhooks.

> **Note**: Some GitHub resources are configured by the [govuk-infrastructure project](https://github.com/alphagov/govuk-infrastructure/blob/main/terraform/deployments/github/README.md). We are considering migrating this configuration to
> Terraform. That we have two ways of configuring GitHub resources is [tracked as tech debt](https://trello.com/c/mojlsebq/226-we-have-two-tools-for-managing-github-resources).

## [Logit](/logit)

Configuration related to Logit, such as Logstash configuration.

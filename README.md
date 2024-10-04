> This repository was archived. 
- GitHub configuration was ported to [govuk-infrastructure](https://github.com/alphagov/govuk-infrastructure/tree/main/terraform/deployments/github)
- Logit configuration was migrated to [govuk-infrastructure](https://github.com/alphagov/govuk-infrastructure/tree/main/docs/logit/logit)
- Verify repos script was migrated to [seal](https://github.com/alphagov/seal/pull/561/files)

# GOV.UK SaaS Config

Collection of scripts to configure Software as a Service applications we use.

## [GitHub](/github)

Tool to make sure all GOV.UK repos have the same settings and webhooks.

> **Note**: Some GitHub resources are configured by the [govuk-infrastructure project](https://github.com/alphagov/govuk-infrastructure/blob/main/terraform/deployments/github/README.md). We are considering migrating this configuration to
> Terraform. That we have two ways of configuring GitHub resources is [tracked as tech debt](https://trello.com/c/mojlsebq/226-we-have-two-tools-for-managing-github-resources).

## Licence

[MIT License](LICENCE)


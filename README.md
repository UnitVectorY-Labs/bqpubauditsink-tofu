[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0) [![Work In Progress](https://img.shields.io/badge/Status-Work%20In%20Progress-yellow)](https://guide.unitvectorylabs.com/bestpractices/status/#work-in-progress)

# bqpubauditsink-tofu

A module for OpenTofu that deploys bqpubauditsink to GCP Cloud Run, along with configuring essential services including the Pub/Sub subscription and BigQuery dataset and table.

## Usage

```hcl
module "bqpubauditsink" {
    source = "git::https://github.com/UnitVectorY-Labs/bqpubauditsink-tofu.git?ref=main"
    name                         = "bqpub"
    project_id                   = var.project_id
    region                       = var.region
    artifact_registry_host       = "us-docker.pkg.dev"
    artifact_registry_name       = "ghcr"
    artifact_registry_project_id = var.project_id
    pubsub_topic                 = "fpas-firepub"
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

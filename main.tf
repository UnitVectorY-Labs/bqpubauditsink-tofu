# Enable required APIs for Cloud Run, Eventarc, Pub/Sub, and Firestore
resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "eventarc" {
  project            = var.project_id
  service            = "eventarc.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "pubsub" {
  project            = var.project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "firestore" {
  project            = var.project_id
  service            = "firestore.googleapis.com"
  disable_on_destroy = false
}

locals {
  final_artifact_registry_project_id = coalesce(var.artifact_registry_project_id, var.project_id)
}

# Service account for Cloud Run services
resource "google_service_account" "cloud_run_sa" {
  project      = var.project_id
  account_id   = "bqpas-${var.name}"
  display_name = "bqpubauditsink Cloud Run (${var.name}) service account"
}

# IAM role to grant permissions to Cloud Run service account for BigQuery
resource "google_bigquery_table_iam_member" "member" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = google_bigquery_table.table.table_id
  role       = "roles/bigquery.dataOwner"
  member     = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Deploy Cloud Run services in specified regions
resource "google_cloud_run_v2_service" "bqpubauditsink" {
  project  = var.project_id
  location = var.region
  name     = "bqpas-${var.name}"
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  deletion_protection = false

  template {
    service_account = google_service_account.cloud_run_sa.email

    containers {
      image = "${var.artifact_registry_host}/${local.final_artifact_registry_project_id}/${var.artifact_registry_name}/unitvectory-labs/bqpubauditsink:${var.bqpubauditsink_tag}"

      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "DATASET_NAME"
        value = var.name
      }
      env {
        name  = "TABLE_NAME"
        value = var.name
      }
    }
  }

  depends_on = [
    google_bigquery_table.table
  ]
}

# Service account for Eventarc triggers
resource "google_service_account" "eventarc_sa" {
  project      = var.project_id
  account_id   = "bqpas-ea-${var.name}"
  display_name = "bqpubauditsink Eventarc (${var.name}) service account"
}

# IAM role to grant invoke permissions to Eventarc service account for Cloud Run services
resource "google_cloud_run_service_iam_member" "invoke_permission" {
  project  = var.project_id
  location = var.region
  service  = google_cloud_run_v2_service.bqpubauditsink.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.eventarc_sa.email}"
}

# Pub/Sub subscription to forward messages to Cloud Run services
resource "google_pubsub_subscription" "pubsub_subscription" {
  project                 = var.project_id
  name                    = "bqpas-${var.name}-${var.region}"
  topic                   = var.pubsub_topic
  enable_message_ordering = true

  push_config {
    push_endpoint = "${google_cloud_run_v2_service.bqpubauditsink.uri}/pubsub"

    oidc_token {
      service_account_email = google_service_account.eventarc_sa.email
    }

    attributes = {
      x-goog-version = "v1"
    }
  }
}

# The BigQuery dataset
resource "google_bigquery_dataset" "dataset" {
  project                    = var.project_id
  dataset_id                 = var.name
  friendly_name              = var.name
  description                = "Dataset for bqpubauditsink (${var.name})"
  location                   = "US"
  delete_contents_on_destroy = true
}

# The BigQuery table to store audit logs
resource "google_bigquery_table" "table" {

  project             = var.project_id
  dataset_id          = google_bigquery_dataset.dataset.dataset_id
  table_id            = var.name
  deletion_protection = false

  clustering = ["database", "documentPath", "timestamp"]

  schema = <<EOF
[
  {
    "name": "documentPath",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "The document path"
  },
  {
    "name": "timestamp",
    "type": "TIMESTAMP",
    "mode": "REQUIRED",
    "description": "The timestamp of the event"
  },
  {
    "name": "database",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "The database name"
  },
  {
    "name": "value",
    "type": "JSON",
    "mode": "NULLABLE",
    "description": "The new value"
  },
  {
    "name": "oldValue",
    "type": "JSON",
    "mode": "NULLABLE",
    "description": "The old value"
  },
  {
    "name": "tombstone",
    "type": "BOOL",
    "mode": "NULLABLE",
    "description": "Indicates if the document is deleted"
  }
]
EOF

}

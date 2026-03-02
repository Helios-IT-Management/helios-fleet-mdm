resource "random_pet" "suffix" {
  count  = var.secret_suffix == null ? 1 : 0
  length = 1
}

locals {
  secret_suffix = coalesce(var.secret_suffix, try(random_pet.suffix[0].id, "default"))
}

resource "random_password" "private_key" {
  length = 32
}

resource "google_secret_manager_secret" "database_password" {
  project   = var.project_id
  secret_id = "fleet-db-password-${local.secret_suffix}"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "database_password" {
  secret      = google_secret_manager_secret.database_password.name
  secret_data = module.mysql.generated_user_password
}

resource "google_secret_manager_secret" "private_key" {
  project   = var.project_id
  secret_id = "fleet-private-key-${local.secret_suffix}"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "private_key" {
  secret      = google_secret_manager_secret.private_key.name
  secret_data = random_password.private_key.result
}
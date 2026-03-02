# GCP Organization and Billing
org_id             = "108770770642"
billing_account_id = "017012-3FF905-0D5AB4"

# DNS Configuration
dns_zone_name   = "fleet.heliosintel.ai."
dns_record_name = "fleet.heliosintel.ai."

# Project
project_name      = "helios-mdm-97c3"
random_project_id = false

# Region/Location
region   = "us-central1"
location = "us"

# Labels
labels = {
  application = "fleetdm"
  environment = "production"
  owner       = "devops-team"
}

# Secret suffix (pin to existing secret names for imported infrastructure)
secret_suffix = "mako"

# Fleet application config
fleet_config = {
  image_tag              = "fleetdm/fleet:v4.81.0"
  installers_bucket_name = "helios-fleet-installers-2024"
  fleet_cpu              = "1000m"
  fleet_memory           = "4096Mi"
  debug_logging          = false
  license_key            = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJGbGVldCBEZXZpY2UgTWFuYWdlbWVudCBJbmMuIiwiZXhwIjoxNzg0OTE2Nzk4LCJzdWIiOiJIZWxpb3MgSW50ZWxsaWdlbmNlIFBsYXRmb3JtcywgSW5jLiIsImRldmljZXMiOjEwLCJub3RlIjoiQ3JlYXRlZCB3aXRoIEZsZWV0IExpY2Vuc2Uga2V5IGRpc3BlbnNlciIsInRpZXIiOiJwcmVtaXVtIiwiaWF0IjoxNzUzMzgwODA1fQ.FurkDySM2_fblHM0L0ImkTSIpnYQsQggI72fSLk2_6DZ9WEOE2pDnqy7P7QSIcX6z8GHnjUTG1Yb6z8JVBhFAQ"
  min_instance_count     = 1
  max_instance_count     = 20
  exec_migration         = true
  use_h2c                = true
  extra_env_vars = {
    FLEET_VULNERABILITIES_DATABASES_PATH                 = "/tmp/vulndbs"
    FLEET_VULNERABILITIES_DISABLE_WIN_OS_VULNERABILITIES = "true"
  }
  extra_secret_env_vars = {}
}

# Database (Cloud SQL for MySQL)
database_config = {
  name                = "fleet-mysql"
  database_name       = "fleet"
  database_user       = "fleet"
  collation           = "utf8mb4_unicode_ci"
  charset             = "utf8mb4"
  deletion_protection = false
  database_version    = "MYSQL_8_0"
  tier                = "db-n1-standard-1"
}

# Cache (Memorystore for Redis)
cache_config = {
  name           = "fleet-cache"
  tier           = "STANDARD_HA"
  engine_version = "REDIS_7_0"
  connect_mode   = "PRIVATE_SERVICE_ACCESS"
  memory_size    = 1
}

# VPC
vpc_config = {
  network_name = "fleet-network"
  subnets = [
    {
      subnet_name           = "fleet-subnet"
      subnet_ip             = "10.10.10.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = true
    }
  ]
}

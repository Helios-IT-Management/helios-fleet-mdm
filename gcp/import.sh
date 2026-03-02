#!/usr/bin/env bash
set -euo pipefail

PROJECT="helios-mdm-97c3"
REGION="us-central1"
SA_EMAIL="fleet-run-sa@${PROJECT}.iam.gserviceaccount.com"
SQL_INSTANCE="fleet-mysql-b7d48efc"
HMAC_ACCESS_ID="GOOG1EGUUUZ2COAN6RXYIWGIMAE3Y3ASUOSMOVVXBWYOMLLSYZZCHDWT3UG7T"

# Helper: import only if not already in state
import_if_missing() {
  local addr="$1"
  local id="$2"
  if terraform state show "$addr" &>/dev/null; then
    echo "SKIP (already in state): $addr"
  else
    terraform import "$addr" "$id"
  fi
}

# ---------------------------------------------------------------------------
# 1. Project Factory
# ---------------------------------------------------------------------------
import_if_missing \
  'module.project_factory.module.project-factory.google_project.main' \
  "$PROJECT"

# google_project_default_service_accounts does not support import.
# It will be handled post-import via terraform plan (no-op if SA already deleted).

# Enabled APIs
APIS=(
  "compute.googleapis.com"
  "sqladmin.googleapis.com"
  "redis.googleapis.com"
  "run.googleapis.com"
  "vpcaccess.googleapis.com"
  "secretmanager.googleapis.com"
  "storage.googleapis.com"
  "dns.googleapis.com"
  "iam.googleapis.com"
  "cloudresourcemanager.googleapis.com"
  "serviceusage.googleapis.com"
  "servicenetworking.googleapis.com"
  "logging.googleapis.com"
  "monitoring.googleapis.com"
  "memorystore.googleapis.com"
  "serviceconsumermanagement.googleapis.com"
  "networkconnectivity.googleapis.com"
)
for api in "${APIS[@]}"; do
  import_if_missing \
    "module.project_factory.module.project-factory.module.project_services.google_project_service.project_services[\"${api}\"]" \
    "${PROJECT}/${api}"
done

# ---------------------------------------------------------------------------
# 2. VPC Network
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.module.vpc.module.vpc.google_compute_network.network' \
  "projects/${PROJECT}/global/networks/fleet-network"

import_if_missing \
  'module.fleet.module.vpc.module.subnets.google_compute_subnetwork.subnetwork["us-central1/fleet-subnet"]' \
  "projects/${PROJECT}/regions/${REGION}/subnetworks/fleet-subnet"

# ---------------------------------------------------------------------------
# 3. Cloud Router + NAT
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.module.cloud_router.google_compute_router.router' \
  "projects/${PROJECT}/regions/${REGION}/routers/fleet-cloud-router"

import_if_missing \
  'module.fleet.module.cloud_router.google_compute_router_nat.nats["fleet-vpc-nat"]' \
  "projects/${PROJECT}/regions/${REGION}/routers/fleet-cloud-router/fleet-vpc-nat"

# ---------------------------------------------------------------------------
# 4. Private Service Access
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.module.private-service-access.google_compute_global_address.google-managed-services-range' \
  "projects/${PROJECT}/global/addresses/google-managed-services-fleet-network"

import_if_missing \
  'module.fleet.module.private-service-access.google_service_networking_connection.private_service_access' \
  "projects/${PROJECT}/global/networks/fleet-network:servicenetworking.googleapis.com"

# ---------------------------------------------------------------------------
# 5. Cloud SQL (MySQL)
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.module.mysql.google_sql_database_instance.default' \
  "projects/${PROJECT}/instances/${SQL_INSTANCE}"

import_if_missing \
  'module.fleet.module.mysql.google_sql_database.default[0]' \
  "projects/${PROJECT}/instances/${SQL_INSTANCE}/databases/fleet"

import_if_missing \
  'module.fleet.module.mysql.google_sql_user.default[0]' \
  "${PROJECT}/${SQL_INSTANCE}/fleet"

# ---------------------------------------------------------------------------
# 6. Memorystore (Redis)
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.module.memstore.google_redis_instance.default' \
  "projects/${PROJECT}/locations/${REGION}/instances/fleet-cache"

# ---------------------------------------------------------------------------
# 7. IAM - Service Account
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.google_service_account.fleet_run_sa' \
  "projects/${PROJECT}/serviceAccounts/${SA_EMAIL}"

import_if_missing \
  'module.fleet.google_project_iam_member.fleet_run_sa_sql_instance_user' \
  "${PROJECT} roles/cloudsql.instanceUser serviceAccount:${SA_EMAIL}"

import_if_missing \
  'module.fleet.google_project_iam_member.fleet_run_sa_log_writer' \
  "${PROJECT} roles/logging.logWriter serviceAccount:${SA_EMAIL}"

import_if_missing \
  'module.fleet.google_project_iam_member.fleet_run_sa_monitoring_writer' \
  "${PROJECT} roles/monitoring.metricWriter serviceAccount:${SA_EMAIL}"

# ---------------------------------------------------------------------------
# 8. Secrets
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.google_secret_manager_secret.database_password' \
  "projects/${PROJECT}/secrets/fleet-db-password-mako"

import_if_missing \
  'module.fleet.google_secret_manager_secret_version.database_password' \
  "projects/${PROJECT}/secrets/fleet-db-password-mako/versions/1"

import_if_missing \
  'module.fleet.google_secret_manager_secret.private_key' \
  "projects/${PROJECT}/secrets/fleet-private-key-mako"

import_if_missing \
  'module.fleet.google_secret_manager_secret_version.private_key' \
  "projects/${PROJECT}/secrets/fleet-private-key-mako/versions/1"

import_if_missing \
  'module.fleet.google_secret_manager_secret_iam_member.fleet_run_sa_db_secret_access' \
  "projects/${PROJECT}/secrets/fleet-db-password-mako roles/secretmanager.secretAccessor serviceAccount:${SA_EMAIL}"

import_if_missing \
  'module.fleet.google_secret_manager_secret_iam_member.fleet_run_sa_private_key_secret_access' \
  "projects/${PROJECT}/secrets/fleet-private-key-mako roles/secretmanager.secretAccessor serviceAccount:${SA_EMAIL}"

# ---------------------------------------------------------------------------
# 9. Storage (GCS Bucket + HMAC)
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.google_storage_bucket.software_installers' \
  "${PROJECT}/helios-fleet-installers-2024"

import_if_missing \
  'module.fleet.google_storage_hmac_key.key' \
  "projects/${PROJECT}/hmacKeys/${HMAC_ACCESS_ID}"

import_if_missing \
  'module.fleet.google_storage_bucket_iam_member.hmac_sa_storage_admin' \
  "b/helios-fleet-installers-2024 roles/storage.objectAdmin serviceAccount:${SA_EMAIL}"

# ---------------------------------------------------------------------------
# 10. Cloud Run Service (via module)
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.module.fleet-service.google_cloud_run_v2_service.main' \
  "projects/${PROJECT}/locations/${REGION}/services/fleet-api"

# ---------------------------------------------------------------------------
# 11. Cloud Run Job (Migrations)
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.google_cloud_run_v2_job.fleet_migration_job' \
  "projects/${PROJECT}/locations/${REGION}/jobs/fleet-migration"

# ---------------------------------------------------------------------------
# 12. Network Endpoint Group (Serverless NEG)
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.google_compute_region_network_endpoint_group.neg' \
  "projects/${PROJECT}/regions/${REGION}/networkEndpointGroups/fleet-neg"

# ---------------------------------------------------------------------------
# 13. Cloud Run IAM (allow LB invoker)
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.google_cloud_run_v2_service_iam_member.allow_lb_invoker' \
  "projects/${PROJECT}/locations/${REGION}/services/fleet-api roles/run.invoker allUsers"

# ---------------------------------------------------------------------------
# 14. Load Balancer (serverless_negs module)
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.module.fleet_lb.google_compute_global_address.default[0]' \
  "projects/${PROJECT}/global/addresses/fleet-lb-address"

import_if_missing \
  'module.fleet.module.fleet_lb.google_compute_backend_service.default["default"]' \
  "projects/${PROJECT}/global/backendServices/fleet-lb-backend-default"

import_if_missing \
  'module.fleet.module.fleet_lb.google_compute_url_map.default[0]' \
  "projects/${PROJECT}/global/urlMaps/fleet-lb-url-map"

import_if_missing \
  'module.fleet.module.fleet_lb.google_compute_url_map.https_redirect[0]' \
  "projects/${PROJECT}/global/urlMaps/fleet-lb-https-redirect"

import_if_missing \
  'module.fleet.module.fleet_lb.google_compute_managed_ssl_certificate.default[0]' \
  "projects/${PROJECT}/global/sslCertificates/fleet-lb-cert"

import_if_missing \
  'module.fleet.module.fleet_lb.google_compute_target_https_proxy.default[0]' \
  "projects/${PROJECT}/global/targetHttpsProxies/fleet-lb-https-proxy"

import_if_missing \
  'module.fleet.module.fleet_lb.google_compute_target_http_proxy.default[0]' \
  "projects/${PROJECT}/global/targetHttpProxies/fleet-lb-http-proxy"

import_if_missing \
  'module.fleet.module.fleet_lb.google_compute_global_forwarding_rule.https[0]' \
  "projects/${PROJECT}/global/forwardingRules/fleet-lb-https"

import_if_missing \
  'module.fleet.module.fleet_lb.google_compute_global_forwarding_rule.http[0]' \
  "projects/${PROJECT}/global/forwardingRules/fleet-lb"

# ---------------------------------------------------------------------------
# 15. DNS
# ---------------------------------------------------------------------------
import_if_missing \
  'module.fleet.google_dns_managed_zone.fleet_dns_zone' \
  "projects/${PROJECT}/managedZones/fleet-zone"

import_if_missing \
  'module.fleet.google_dns_record_set.fleet_dns_record' \
  "${PROJECT}/fleet-zone/fleet.heliosintel.ai./A"

echo ""
echo "========================================="
echo "Import complete. Run 'terraform plan' to review."
echo "========================================="

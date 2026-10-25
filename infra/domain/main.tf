# One global HTTPS load balancer for every experiment:
#
#   example.com        -> Cloud Run service `apex_service`
#   <slug>.example.com -> Cloud Run service `<slug>`
#
# The wildcard route uses a serverless NEG URL mask, so a new Cloud Run
# service is reachable at its subdomain as soon as it is deployed, with no
# Terraform changes. A single wildcard certificate covers every subdomain.

resource "google_compute_global_address" "this" {
  name = "experiments"
}

# --- Backends -----------------------------------------------------------------

resource "google_compute_region_network_endpoint_group" "apex" {
  name                  = "experiments-apex"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.apex_service
  }
}

resource "google_compute_region_network_endpoint_group" "wildcard" {
  name                  = "experiments-wildcard"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    url_mask = "<service>.${var.domain}"
  }
}

resource "google_compute_backend_service" "apex" {
  name                  = "experiments-apex"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"

  backend {
    group = google_compute_region_network_endpoint_group.apex.id
  }
}

resource "google_compute_backend_service" "wildcard" {
  name                  = "experiments-wildcard"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"

  backend {
    group = google_compute_region_network_endpoint_group.wildcard.id
  }
}

resource "google_compute_url_map" "https" {
  name            = "experiments"
  default_service = google_compute_backend_service.wildcard.id

  host_rule {
    hosts        = [var.domain]
    path_matcher = "apex"
  }

  path_matcher {
    name            = "apex"
    default_service = google_compute_backend_service.apex.id
  }
}

# --- Certificate (apex + wildcard, via DNS authorization) ---------------------

resource "google_certificate_manager_dns_authorization" "this" {
  name   = "experiments"
  domain = var.domain
}

resource "google_certificate_manager_certificate" "this" {
  name = "experiments"

  managed {
    domains            = [var.domain, "*.${var.domain}"]
    dns_authorizations = [google_certificate_manager_dns_authorization.this.id]
  }
}

resource "google_certificate_manager_certificate_map" "this" {
  name = "experiments"
}

resource "google_certificate_manager_certificate_map_entry" "this" {
  name         = "experiments"
  map          = google_certificate_manager_certificate_map.this.name
  certificates = [google_certificate_manager_certificate.this.id]
  matcher      = "PRIMARY"
}

# --- Frontends ----------------------------------------------------------------

resource "google_compute_target_https_proxy" "this" {
  name            = "experiments"
  url_map         = google_compute_url_map.https.id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.this.id}"
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "experiments-https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.this.id
  port_range            = "443"
  target                = google_compute_target_https_proxy.this.id
}

# Plain HTTP just redirects to HTTPS.
resource "google_compute_url_map" "http_redirect" {
  name = "experiments-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "this" {
  name    = "experiments-http"
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "experiments-http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.this.id
  port_range            = "80"
  target                = google_compute_target_http_proxy.this.id
}

# --- DNS (only when the zone lives in Cloud DNS) ------------------------------

locals {
  dns_auth = google_certificate_manager_dns_authorization.this.dns_resource_record[0]

  # Static keys so for_each works before the values are known.
  dns_records = {
    apex     = { name = "${var.domain}.", type = "A", data = google_compute_global_address.this.address }
    wildcard = { name = "*.${var.domain}.", type = "A", data = google_compute_global_address.this.address }
    acme     = { name = local.dns_auth.name, type = local.dns_auth.type, data = local.dns_auth.data }
  }
}

resource "google_dns_record_set" "this" {
  for_each = var.dns_managed_zone == "" ? {} : local.dns_records

  managed_zone = var.dns_managed_zone
  name         = each.value.name
  type         = each.value.type
  ttl          = 300
  rrdatas      = [each.value.data]
}

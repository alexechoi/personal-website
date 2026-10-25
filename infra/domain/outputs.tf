output "ip_address" {
  value = google_compute_global_address.this.address
}

output "dns_records" {
  value = values(local.dns_records)
}

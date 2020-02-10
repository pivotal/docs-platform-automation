locals  {
  concourse_url = "ci.${var.environment_name}.${data.google_dns_managed_zone.hosted-zone.dns_name}"
}

resource "google_dns_record_set" "concourse" {
  name = local.concourse_url
  type = "A"
  ttl  = 60

  managed_zone = var.hosted_zone

  rrdatas = [google_compute_address.concourse.address]
}

//create a load balancer for concourse
resource "google_compute_address" "concourse" {
  name = "${var.environment_name}-concourse"
}

resource "google_compute_firewall" "concourse" {
  allow {
    ports    = ["443", "2222", "8844", "8443"]
    protocol = "tcp"
  }

  direction     = "INGRESS"
  name          = "${var.environment_name}-concourse-open"
  network       = google_compute_network.network.self_link
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["concourse"]
}

resource "google_compute_forwarding_rule" "concourse_credhub" {
  ip_address  = google_compute_address.concourse.address
  ip_protocol = "TCP"
  name        = "${var.environment_name}-concourse-credhub"
  port_range  = "8844-8844"
  target      = google_compute_target_pool.concourse_target_pool.self_link
}

resource "google_compute_forwarding_rule" "concourse_ssh" {
  ip_address  = google_compute_address.concourse.address
  ip_protocol = "TCP"
  name        = "${var.environment_name}-concourse-ssh"
  port_range  = "2222-2222"
  target      = google_compute_target_pool.concourse_target_pool.self_link
}

resource "google_compute_forwarding_rule" "concourse_tcp" {
  ip_address  = google_compute_address.concourse.address
  ip_protocol = "TCP"
  name        = "${var.environment_name}-concourse-tcp"
  port_range  = "443-443"
  target      = google_compute_target_pool.concourse_target_pool.self_link
}

resource "google_compute_forwarding_rule" "concourse_uaa" {
  ip_address  = google_compute_address.concourse.address
  ip_protocol = "TCP"
  name        = "${var.environment_name}-concourse-uaa"
  port_range  = "8443-8443"
  target      = google_compute_target_pool.concourse_target_pool.self_link
}

resource "google_compute_target_pool" "concourse_target_pool" {
  name = "${var.environment_name}-concourse"
}

output "concourse_url" {
  value = local.concourse_url
}

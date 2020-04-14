resource "nsxt_lb_service" "concourse_lb_service" {
  description  = "concourse lb_service"
  display_name = "${var.environment_name}_concourse_lb_service"

  enabled           = true
  logical_router_id = nsxt_logical_tier1_router.t1_infrastructure.id
  virtual_server_ids = ["${nsxt_lb_tcp_virtual_server.concourse_lb_virtual_server.id}"]
  error_log_level   = "INFO"
  size              = "SMALL"

  depends_on        = ["nsxt_logical_router_link_port_on_tier1.t1_infrastructure_to_t0"]

  tag {
    scope = "terraform"
    tag   = var.environment_name
  }
}

resource "nsxt_ns_group" "concourse_ns_group" {
  display_name = "${var.environment_name}_concourse_ns_group"

  tag {
    scope = "terraform"
    tag   = var.environment_name
  }
}

resource "nsxt_lb_tcp_monitor" "concourse_lb_tcp_monitor" {
  display_name = "${var.environment_name}_concourse_lb_tcp_monitor"
  interval     = 5
  monitor_port  = 443
  rise_count    = 3
  fall_count    = 3
  timeout      = 15

  tag {
    scope = "terraform"
    tag   = var.environment_name
  }
}

resource "nsxt_lb_pool" "concourse_lb_pool" {
  description              = "concourse_lb_pool provisioned by Terraform"
  display_name             = "${var.environment_name}_concourse_lb_pool"
  algorithm                = "WEIGHTED_ROUND_ROBIN"
  min_active_members       = 1
  tcp_multiplexing_enabled = false
  tcp_multiplexing_number  = 3
  active_monitor_id        = "${nsxt_lb_tcp_monitor.concourse_lb_tcp_monitor.id}"
  snat_translation {
    type          = "SNAT_AUTO_MAP"
  }
  member_group {
    grouping_object {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.concourse_ns_group.id}"
    }
  }

  tag {
    scope = "terraform"
    tag   = var.environment_name
  }
}

resource "nsxt_lb_fast_tcp_application_profile" "tcp_profile" {
  display_name = "${var.environment_name}_concourse_fast_tcp_profile"

  tag {
    scope = "terraform"
    tag   = var.environment_name
  }
}

resource "nsxt_lb_tcp_virtual_server" "concourse_lb_virtual_server" {
  description                = "concourse lb_virtual_server provisioned by terraform"
  display_name               = "${var.environment_name}_concourse virtual server"
  application_profile_id     = "${nsxt_lb_fast_tcp_application_profile.tcp_profile.id}"
  ip_address                 = "${var.nsxt_lb_concourse_virtual_server_ip_address}"
  ports                       = ["443","8443","8844"]
  pool_id                    = "${nsxt_lb_pool.concourse_lb_pool.id}"

  tag {
    scope = "terraform"
    tag   = var.environment_name
  }
}

variable "nsxt_lb_concourse_virtual_server_ip_address" {
  default     = ""
  description = "IP Address for concourse loadbalancer"
  type        = "string"
}

output "concourse_url" {
  value = var.nsxt_lb_concourse_virtual_server_ip_address
}
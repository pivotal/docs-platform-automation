resource "azurerm_public_ip" "concourse" {
  name                         = "${var.environment_name}-concourse-lb"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.platform.name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags {
    environment = var.environment_name
  }
}

resource "azurerm_lb" "concourse" {
  name                = "${var.environment_name}-concourse-lb"
  resource_group_name = azurerm_resource_group.platform.name
  location            = var.location
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "${var.environment_name}-concourse-frontend-ip-configuration"
    public_ip_address_id = azurerm_public_ip.concourse.id
  }
}

resource "azurerm_lb_rule" "concourse-https" {
  name                = "${var.environment_name}-concourse-https"
  resource_group_name = azurerm_resource_group.platform.name
  loadbalancer_id     = azurerm_lb.concourse.id

  frontend_ip_configuration_name = "${var.environment_name}-concourse-frontend-ip-configuration"
  protocol                       = "TCP"
  frontend_port                  = 443
  backend_port                   = 443

  backend_address_pool_id = azurerm_lb_backend_address_pool.concourse.id
  probe_id                = azurerm_lb_probe.concourse-https.id
}

resource "azurerm_lb_probe" "concourse-https" {
  name                = "${var.environment_name}-concourse-https"
  resource_group_name = azurerm_resource_group.platform.name
  loadbalancer_id     = azurerm_lb.concourse.id
  protocol            = "TCP"
  port                = 443
}

resource "azurerm_lb_rule" "concourse-http" {
  name                = "${var.environment_name}-concourse-http"
  resource_group_name = azurerm_resource_group.platform.name
  loadbalancer_id     = azurerm_lb.concourse.id

  frontend_ip_configuration_name = "${var.environment_name}-concourse-frontend-ip-configuration"
  protocol                       = "TCP"
  frontend_port                  = 80
  backend_port                   = 80

  backend_address_pool_id = azurerm_lb_backend_address_pool.concourse.id
  probe_id                = azurerm_lb_probe.concourse-http.id
}

resource "azurerm_lb_probe" "concourse-http" {
  name                = "${var.environment_name}-concourse-http"
  resource_group_name = azurerm_resource_group.platform.name
  loadbalancer_id     = azurerm_lb.concourse.id
  protocol            = "TCP"
  port                = 80
}

resource "azurerm_lb_rule" "concourse-uaa" {
  name                = "${var.environment_name}-concourse-uaa"
  resource_group_name = azurerm_resource_group.platform.name
  loadbalancer_id     = azurerm_lb.concourse.id

  frontend_ip_configuration_name = "${var.environment_name}-concourse-frontend-ip-configuration"
  protocol                       = "TCP"
  frontend_port                  = 8443
  backend_port                   = 8443

  backend_address_pool_id = azurerm_lb_backend_address_pool.concourse.id
  probe_id                = azurerm_lb_probe.concourse-uaa.id
}

resource "azurerm_lb_probe" "concourse-uaa" {
  name                = "${var.environment_name}-concourse-uaa"
  resource_group_name = azurerm_resource_group.platform.name
  loadbalancer_id     = azurerm_lb.concourse.id
  protocol            = "TCP"
  port                = 8443
}

resource "azurerm_lb_rule" "concourse-credhub" {
  name                = "${var.environment_name}-concourse-credhub"
  resource_group_name = azurerm_resource_group.platform.name
  loadbalancer_id     = azurerm_lb.concourse.id

  frontend_ip_configuration_name = "${var.environment_name}-concourse-frontend-ip-configuration"
  protocol                       = "TCP"
  frontend_port                  = 8844
  backend_port                   = 8844

  backend_address_pool_id = azurerm_lb_backend_address_pool.concourse.id
  probe_id                = azurerm_lb_probe.concourse-credhub.id
}

resource "azurerm_lb_probe" "concourse-credhub" {
  name                = "${var.environment_name}-concourse-credhub"
  resource_group_name = azurerm_resource_group.platform.name
  loadbalancer_id     = azurerm_lb.concourse.id
  protocol            = "TCP"
  port                = 8844
}

resource "azurerm_network_security_rule" "concourse-http" {
  name                        = "${var.environment_name}-concourse-http"
  priority                    = 209
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.platform.name
  network_security_group_name = azurerm_network_security_group.platform.name
}

resource "azurerm_network_security_rule" "concourse-https" {
  name                        = "${var.environment_name}-concourse-https"
  priority                    = 208
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.platform.name
  network_security_group_name = azurerm_network_security_group.platform.name
}

resource "azurerm_network_security_rule" "concourse-credhub" {
  name                        = "${var.environment_name}-uaa"
  priority                    = 207
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8844"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.platform.name
  network_security_group_name = azurerm_network_security_group.platform.name
}

resource "azurerm_network_security_rule" "uaa" {
  name                        = "${var.environment_name}-uaa"
  priority                    = 206
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.platform.name
  network_security_group_name = azurerm_network_security_group.platform.name
}

resource "azurerm_lb_backend_address_pool" "concourse" {
  name                = "${var.environment_name}-concourse-backend-pool"
  resource_group_name = azurerm_resource_group.platform.name
  loadbalancer_id     = azurerm_lb.concourse.id
}

resource "azurerm_dns_a_record" "concourse" {
  name                = "ci.${var.environment_name}"
  zone_name           = data.azurerm_dns_zone.hosted.name
  resource_group_name = data.azurerm_dns_zone.hosted.resource_group_name
  ttl                 = "60"
  records             = [azurerm_public_ip.concourse.ip_address]

  tags = merge(
    var.tags,
    { name = "ci.${var.environment_name}" },
  )
}

output "concourse_url" {
  value  = "${azurerm_dns_a_record.concourse.name}.${azurerm_dns_a_record.concourse.zone_name}"
}
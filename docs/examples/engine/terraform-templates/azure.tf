resource "azurerm_public_ip" "concourse" {
  name                         = "${var.environment_name}-concourse-lb"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.platform.name
  allocation_method            = "Static"
  sku                          = "Basic"

  tags = {
    environment = var.environment_name
  }
}

resource "azurerm_lb" "concourse" {
  name                = "${var.environment_name}-concourse-lb"
  resource_group_name = azurerm_resource_group.platform.name
  location            = var.location
  sku                 = "Basic"

  frontend_ip_configuration {
    name                 = "${var.environment_name}-concourse-frontend-ip-configuration"
    public_ip_address_id = azurerm_public_ip.concourse.id
  }
}

resource "azurerm_lb_backend_address_pool" "concourse" {
  name                = "${var.environment_name}-concourse-backend-pool"
  resource_group_name = azurerm_resource_group.platform.name
  loadbalancer_id     = azurerm_lb.concourse.id
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

resource "azurerm_subnet" "concourse" {
  name = "${var.environment_name}-pas-subnet"

  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.platform.name
  address_prefix       = "10.0.16.0/24"

  network_security_group_id = azurerm_network_security_group.concourse.id # Deprecated but required until AzureRM Provider 2.0
}

resource "azurerm_subnet_network_security_group_association" "concourse" {
  subnet_id                 = azurerm_subnet.concourse.id
  network_security_group_id = azurerm_network_security_group.concourse.id

  depends_on = [
    azurerm_subnet.concourse,
    azurerm_network_security_group.concourse
  ]
}

resource "azurerm_network_security_group" "concourse" {
  name                = "${var.environment_name}-concourse-network-sg"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform.name

  security_rule {
    name                                       = "https"
    priority                                   = 100
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "443"
    source_address_prefix                      = "*"
  }

  security_rule {
    name                                       = "ssh"
    priority                                   = 100
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "2222"
    source_address_prefix                      = "*"
  }

  security_rule {
    name                                       = "uaa"
    priority                                   = 100
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "8443"
    source_address_prefix                      = "*"
  }

  security_rule {
    name                                       = "credhub"
    priority                                   = 100
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_range                     = "8844"
    source_address_prefix                      = "*"
  }

  tags = merge(
    var.tags,
    { name = "${var.environment_name}-concourse-network-sg" },
  )
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

output "stable_config" {
  value     = jsonencode(merge(local.stable_config, {
    "concourse_subnet_name"    = azurerm_subnet.concourse.name,
    "concourse_subnet_id"      = azurerm_subnet.concourse.id,
    "concourse_subnet_cidr"    = azurerm_subnet.concourse.address_prefix,
    "concourse_subnet_gateway" = cidrhost(azurerm_subnet.concourse.address_prefix, 1),
    "concourse_subnet_range"   = cidrhost(azurerm_subnet.concourse.address_prefix, 10)
  }))
}
# Configure the Azure provider
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create a resource group for the hub resources
resource "azurerm_resource_group" "hub_rg" {
  name     = "rg-${var.prefix}-hub-${var.location}"
  location = var.location
  tags     = var.tags
}

# Create the hub virtual network
resource "azurerm_virtual_network" "hub_vnet" {
  name                = "vnet-${var.prefix}-hub-${var.location}"
  address_space       = [var.hub_address_space]
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  tags                = var.tags
}

# Create subnets in the hub virtual network
resource "azurerm_subnet" "hub_bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = [cidrsubnet(var.hub_address_space, 8, 0)]
}

resource "azurerm_subnet" "hub_gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = [cidrsubnet(var.hub_address_space, 8, 1)]
}

# Create a resource group for the spoke resources
resource "azurerm_resource_group" "spoke_rg" {
  name     = "rg-${var.prefix}-spoke-${var.location}"
  location = var.location
  tags     = var.tags
}

# Create the spoke virtual network
resource "azurerm_virtual_network" "spoke_vnet" {
  name                = "vnet-${var.prefix}-spoke-${var.location}"
  address_space       = [var.spoke_address_space]
  location            = azurerm_resource_group.spoke_rg.location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  tags                = var.tags
}

# Create subnets in the spoke virtual network
resource "azurerm_subnet" "spoke_web_subnet" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.spoke_rg.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = [cidrsubnet(var.spoke_address_space, 8, 0)]
}

resource "azurerm_subnet" "spoke_data_subnet" {
  name                 = "snet-data"
  resource_group_name  = azurerm_resource_group.spoke_rg.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = [cidrsubnet(var.spoke_address_space, 8, 1)]
}

# Create network security groups
resource "azurerm_network_security_group" "web_nsg" {
  name                = "nsg-${var.prefix}-web"
  location            = azurerm_resource_group.spoke_rg.location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  tags                = var.tags

  security_rule {
    name                       = "AllowHTTPInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with web subnet
resource "azurerm_subnet_network_security_group_association" "web_nsg_association" {
  subnet_id                 = azurerm_subnet.spoke_web_subnet.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

# Create VNet peering from hub to spoke
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-${var.prefix}-hub-to-spoke"
  resource_group_name       = azurerm_resource_group.hub_rg.name
  virtual_network_name      = azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_vnet.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
}

# Create VNet peering from spoke to hub
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${var.prefix}-spoke-to-hub"
  resource_group_name       = azurerm_resource_group.spoke_rg.name
  virtual_network_name      = azurerm_virtual_network.spoke_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub_vnet.id
  allow_forwarded_traffic   = true
  use_remote_gateways       = false # Set to true if you have a gateway in the hub
}

# Create a public IP for Bastion
resource "azurerm_public_ip" "bastion_pip" {
  name                = "pip-${var.prefix}-bastion"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Create Azure Bastion service
resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-${var.prefix}"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.hub_bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}

# Create a jumpbox VM in the hub network
resource "azurerm_network_interface" "jumpbox_nic" {
  name                = "nic-${var.prefix}-jumpbox"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.hub_gateway_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                = "vm-${var.prefix}-jumpbox"
  resource_group_name = azurerm_resource_group.hub_rg.name
  location            = azurerm_resource_group.hub_rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = var.tags

  network_interface_ids = [
    azurerm_network_interface.jumpbox_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    product   = "22_04-lts"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Create a public IP for the web server
resource "azurerm_public_ip" "web_pip" {
  name                = "pip-${var.prefix}-web"
  location            = azurerm_resource_group.spoke_rg.location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Create network interface for web server
resource "azurerm_network_interface" "web_nic" {
  name                = "nic-${var.prefix}-web"
  location            = azurerm_resource_group.spoke_rg.location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.spoke_web_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web_pip.id
  }
}

# Create web server VM
resource "azurerm_linux_virtual_machine" "web" {
  name                = "vm-${var.prefix}-web"
  resource_group_name = azurerm_resource_group.spoke_rg.name
  location            = azurerm_resource_group.spoke_rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = var.tags

  network_interface_ids = [
    azurerm_network_interface.web_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    product   = "22_04-lts"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Install Nginx on the web server using custom script extension
resource "azurerm_virtual_machine_extension" "web_nginx" {
  name                 = "install-nginx"
  virtual_machine_id   = azurerm_linux_virtual_machine.web.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = <<SETTINGS
    {
        "fileUris": ["https://raw.githubusercontent.com/${var.github_username}/azure-hub-spoke-lz/main/scripts/install_nginx.sh"],
        "commandToExecute": "bash install_nginx.sh"
    }
SETTINGS
}

# Create Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "monitoring" {
  name                = "log-${var.prefix}-${var.location}"
  location            = azurerm_resource_group.spoke_rg.location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Create an action group for alerts
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${var.prefix}-alerts"
  resource_group_name = azurerm_resource_group.spoke_rg.name
  short_name          = "alerts"

  email_receiver {
    name                    = "Admin"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# Create a CPU alert for the web server
resource "azurerm_monitor_metric_alert" "web_cpu_alert" {
  name                = "alert-${var.prefix}-web-cpu"
  resource_group_name = azurerm_resource_group.spoke_rg.name
  scopes              = [azurerm_linux_virtual_machine.web.id]
  description         = "Action will be triggered when CPU usage is greater than 80%"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  window_size              = "PT5M"
  frequency                = "PT1M"
  severity                 = 2
  auto_mitigate            = false

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Create an Azure Policy assignment (allowed locations)
resource "azurerm_policy_assignment" "allowed_locations" {
  name                 = "policy-${var.prefix}-allowed-locations"
  scope                = azurerm_resource_group.spoke_rg.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  description          = "Policy to allow resource creation only in approved locations"
  display_name         = "Allowed Locations"

  parameters = <<PARAMETERS
    {
      "listOfAllowedLocations": {
        "value": [var.location]
      }
    }
  PARAMETERS
}

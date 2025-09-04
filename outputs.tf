output "bastion_host_name" {
  description = "Name of the Azure Bastion host"
  value       = azurerm_bastion_host.bastion.name
}

output "web_vm_public_ip" {
  description = "Public IP address of the web server"
  value       = azurerm_public_ip.web_pip.ip_address
}

output "jumpbox_vm_name" {
  description = "Name of the jumpbox VM"
  value       = azurerm_linux_virtual_machine.jumpbox.name
}

output "web_vm_name" {
  description = "Name of the web server VM"
  value       = azurerm_linux_virtual_machine.web.name
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.monitoring.id
}

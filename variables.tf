variable "prefix" {
  description = "Prefix for all resources"
  type        = string
  default     = "az104"
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "eastus2"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Demo"
    Project     = "AZ-104 Landing Zone"
  }
}

variable "hub_address_space" {
  description = "Address space for the hub virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "spoke_address_space" {
  description = "Address space for the spoke virtual network"
  type        = string
  default     = "10.1.0.0/16"
}

variable "vm_size" {
  description = "Size of the virtual machines"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the virtual machines"
  type        = string
  default     = "az104admin"
}

variable "alert_email" {
  description = "Email address to send alerts to"
  type        = string
}

variable "github_username" {
  description = "GitHub username for the custom script extension"
  type        = string
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.86.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
}

resource "azurerm_resource_group" "power_bi_RG" {
  name     = "power_bi_RG"
  location = "UK West"
}

resource "azurerm_virtual_network" "power_BI_VNET" {
  name                = "power_BI_VNET"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.power_bi_RG.location
  resource_group_name = azurerm_resource_group.power_bi_RG.name
}

resource "azurerm_subnet" "power_BI_SNET" {
  name                 = "power_BI_SNET"
  resource_group_name  = azurerm_resource_group.power_bi_RG.name
  virtual_network_name = azurerm_virtual_network.power_BI_VNET.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "power_BI_NI" {
  name                = "power_BI_NI"
  location            = azurerm_resource_group.power_bi_RG.location
  resource_group_name = azurerm_resource_group.power_bi_RG.name
  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.power_BI_SNET.id
    public_ip_address_id          = azurerm_public_ip.vm_public_IP.id
  }
}

resource "azurerm_public_ip" "vm_public_IP" {
  name                = "vm_public_IP"
  resource_group_name = azurerm_resource_group.power_bi_RG.name
  location            = azurerm_resource_group.power_bi_RG.location
  allocation_method   = "Dynamic"

  #   create_before_destroy = true - might be needed
}

resource "azurerm_windows_virtual_machine" "power_bi_vm" {
  name                = "power-bi-vm"
  resource_group_name = azurerm_resource_group.power_bi_RG.name
  location            = azurerm_resource_group.power_bi_RG.location
  size                = "Standard_D2s_v3"
  #   take login out of file
  admin_username = var.username
  admin_password = var.password
  network_interface_ids = [
    azurerm_network_interface.power_BI_NI.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    # maybe update SKU?
    sku     = "win10-22h2-pro-g2"
    version = "latest"
  }
}

resource "azurerm_network_security_group" "power_bi_SG" {
  name                = "power_bi_SG"
  location            = azurerm_resource_group.power_bi_RG.location
  resource_group_name = azurerm_resource_group.power_bi_RG.name
}

resource "azurerm_network_security_rule" "allow_RDP" {
  name                        = "allow_RDP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.power_bi_RG.name
  network_security_group_name = azurerm_network_security_group.power_bi_SG.name
}

data "azurerm_shared_image_version" "powerbi_vm_image_version" {
  name = var.powerbi_vm_image_name
  image_name = var.powerbi_vm_image_image_name
  gallery_name = var.powerbi_vm_image_gallery_name
  resource_group_name = data.azurerm_resource_group.power_bi_RG.name
}

# do i need a resource block in here, as per the below ??
# resource "azurerm_image" "example" {
#   name                      = "exampleimage"
#   location                  = data.azurerm_virtual_machine.example.location
#   resource_group_name       = data.azurerm_virtual_machine.example.name
#   source_virtual_machine_id = data.azurerm_virtual_machine.example.id
# }

output "vm_ip" {
  value = ["${azurerm_windows_virtual_machine.power_bi_vm.*.public_ip_address}"]
  # might not work as its trying to export all
}
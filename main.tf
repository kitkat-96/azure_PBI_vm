terraform {
}

provider "azurerm" {
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

resource "azurerm_network_interface" "power_BI_NI" {
  name                = "power_BI_NI"
  location            = azurerm_resource_group.power_bi_RG.location
  resource_group_name = azurerm_resource_group.power_bi_RG.name
  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
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
  name                = "power_bi_vm"
  resource_group_name = azurerm_resource_group.power_bi_RG.name
  location            = azurerm_resource_group.power_bi_RG.location
  size                = "Standard_D2s_v3"
#   take login out of file
  admin_username      = "klovell96"
  admin_password      = "VMPowerBI44!!"
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
    sku       = "win10-22h2-pro-g2"
    version   = "latest"
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
  resource_group_name         = azurerm_resource_group.power_bi_RG.name
  network_security_group_name = azurerm_network_security_group.power_bi_SG.name
}

# output "vm_ip" {
#   value = ["${azurerm_windows_virtual_machine.power_bi_vm.*.public_ip_address}"]
# might not work as its trying to export all
# }
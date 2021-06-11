# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "yz4898-eastus-test-rg" {
  name     = "yz4898-eastus-test-rg"
  location = "eastus"

  tags = {
    environment = "Terraform Demo"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "yz4898-eastus-test-vnet" {
  name                = "yz4898-eastus-test-vnet"
  address_space       = ["10.0.0.0/16", "172.24.0.0/16", "192.168.0.0/16"]
  location            = "eastus"
  resource_group_name = azurerm_resource_group.yz4898-eastus-test-rg.name

  tags = {
    environment = "Terraform Demo"
  }
}

# Create subnet
resource "azurerm_subnet" "client-subnet" {
  name                 = "client-subnet"
  resource_group_name  = azurerm_resource_group.yz4898-eastus-test-rg.name
  virtual_network_name = azurerm_virtual_network.yz4898-eastus-test-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "client-pip" {
  name                = "client-pip"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.yz4898-eastus-test-rg.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "Terraform Demo"
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "yz4898-eastus-client-nsg" {
  name                = "yz4898-eastus-client-nsg"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.yz4898-eastus-test-rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "70.135.70.253/32,136.49.156.194/32"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Terraform Demo"
  }
}

# Create network interface
resource "azurerm_network_interface" "client-nic" {
  name                = "client-nic"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.yz4898-eastus-test-rg.name

  ip_configuration {
    name                          = "client-nicConfiguration"
    subnet_id                     = azurerm_subnet.client-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.client-pip.id
  }

  tags = {
    environment = "Terraform Demo"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.client-nic.id
  network_security_group_id = azurerm_network_security_group.yz4898-eastus-client-nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.yz4898-eastus-test-rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "yz4898storageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = azurerm_resource_group.yz4898-eastus-test-rg.name
  location                 = "eastus"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "Terraform Demo"
  }
}

# Create (and display) an SSH key
resource "tls_private_key" "yz4898_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
output "tls_private_key" {
  value     = tls_private_key.yz4898_ssh.private_key_pem
  sensitive = true
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "clientVM" {
  name                  = "client"
  location              = "eastus"
  resource_group_name   = azurerm_resource_group.yz4898-eastus-test-rg.name
  network_interface_ids = [azurerm_network_interface.client-nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "clientOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "client"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.yz4898storageaccount.primary_blob_endpoint
  }

  tags = {
    environment = "Terraform Demo"
  }
}

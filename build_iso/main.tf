provider "vault" {
  address         = "http://127.0.0.1:8200/"
  skip_tls_verify = true
  token           = var.vault_token
}

data "vault_generic_secret" "vcenterpass" {
  path = "vcenter/vcenterpass"
}

 provider "vsphere" {
  user           = var.vsphere_user
  password       = data.vault_generic_secret.vcenterpass.data["password"]
  vsphere_server = var.vsphere_server
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.vsphere_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_content_library" "iso_library" {
  name = var.iso_library
}

# Upload iso file to content lib
# Note it will take time..
resource "vsphere_content_library_item" "photon_iso" {
  name        = "ph4-rt-refresh_adj"
  description = "ph4-rt-refresh_adj"
  file_url    = "ph4-rt-refresh_adj.iso"
  library_id  = data.vsphere_content_library.iso_library.id
  type        = "iso"
}

# Upload iso file to content lib
# Note it will take time..
data "vsphere_content_library_item" "library_item_photon" {
   name       = "ph4-rt-refresh_adj"
   type       = "iso"
   library_id = data.vsphere_content_library.iso_library.id
 }

# Upload iso file to datacenter
# Note normally we would like to use content lib
# I open a bug to fix issue so we can boot VM with CDROM that uses iso from content library.
# For now we just use vsan datastore.
 resource "vsphere_file" "photon_iso_upload" {
   datacenter         = var.vsphere_datacenter
   datastore          = var.vsphere_datastore
   source_file        = "ph4-rt-refresh_adj.iso"
   destination_file   = "/ISO/ph4-rt-refresh_adj.iso"
   create_directories = true
 }

resource "random_id" "server" {
  byte_length = 8
}

resource "vsphere_virtual_machine" "vm" {
  name             = "foo01 ${random_id.server.hex}"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  num_cpus         = 4
  memory           = 8192
  guest_id         = "other3xLinux64Guest"

  cdrom {
    datastore_id = data.vsphere_datastore.datastore.id
    path         = "/ISO/ph4-rt-refresh_adj.iso"
  }

  network_interface {
    network_id = data.vsphere_network.network.id
  }
  disk {
    label = "disk0"
    size  = 40
  }
#   extra_config = {
#     "guestinfo.metadata"          = base64encode(file("${path.module}/metadata.yml"))
#     "guestinfo.metadata.encoding" = "base64"
#     "guestinfo.userdata"          = base64encode(file("${path.module}/userdata.yml"))
#     "guestinfo.userdata.encoding" = "base64"
#   }
}



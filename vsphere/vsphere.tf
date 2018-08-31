# vsphere related setup 

######### Provider info ############
provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}
#################variables ##########
variable "datacenter" {
  default = "dc1"
}
variable "hosts" {
  default = [
    "esxi1",
    "esxi2",
    "esxi3",
  ]
}

variable "network_interfaces" {
  default = [
    "vmnic0",
    "vmnic1",
    "vmnic2",
    "vmnic3",
  ]
}
############# Data ############

data "vsphere_datacenter" "dc" {
	name = "${var.datacenter}"
}

data "vsphere_datastore" "datastore" {
  name          = "datastore1"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_host" "hosts" {
  count         = "${length(var.hosts)}"
  name          = "${var.hosts[count.index]}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
  name          = "cluster1/Resources"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "public"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

####### ##########Resources ################

####### Compute cluster resource ################

resource "vsphere_compute_cluster" "compute_cluster" {
  name            = "terraform-compute-cluster-test"
  datacenter_id   = "${data.vsphere_datacenter.dc.id}"
  host_system_ids = ["${data.vsphere_host.hosts.*.id}"]

  drs_enabled          = true
  drs_automation_level = "fullyAutomated"

  ha_enabled = true
}
################# Custer host group # ############
resource "vsphere_compute_cluster_host_group" "cluster_host_group" {
  name                = "terraform-test-cluster-host-group"
  compute_cluster_id  = "${vsphere_compute_cluster.compute_cluster.id}"
  host_system_ids     = ["${data.vsphere_host.hosts.*.id}"]
}

################# Storage resources ###################

resource "vsphere_datastore_cluster" "datastore_cluster" {
  name          = "terraform-datastore-cluster-test"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
  sdrs_enabled  = true
}

resource "vsphere_nas_datastore" "datastore1" {
  name                 = "terraform-datastore-test1"
  host_system_ids      = ["${data.vsphere_host.esxi_hosts.*.id}"]
  datastore_cluster_id = "${vsphere_datastore_cluster.datastore_cluster.id}"

  type         = "NFS"
  remote_hosts = ["nfs"]
  remote_path  = "/export/terraform-test1"
}

resource "vsphere_nas_datastore" "datastore2" {
  name                 = "terraform-datastore-test2"
  host_system_ids      = ["${data.vsphere_host.esxi_hosts.*.id}"]
  datastore_cluster_id = "${vsphere_datastore_cluster.datastore_cluster.id}"

  type         = "NFS"
  remote_hosts = ["nfs"]
  remote_path  = "/export/terraform-test2"
}

################# VM resource # ############
data "vsphere_virtual_machine" "template" {
  name          = "ubuntu-16.04"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_virtual_disk" "myDisk" {
  size         = 2
  vmdk_path    = "myDisk.vmdk"
  datacenter   = "Datacenter"
  datastore    = "local"
  type         = "thin"
}

resource "vsphere_virtual_machine" "vm" {
  name             = "terraform-test"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"

  num_cpus = 2
  memory   = 1024
  guest_id = "other3xLinux64Guest"

  network_interface {
    network_id = "${data.vsphere_network.network.id}"
  }
  
  disk {
    label = "disk0"
    size  = 20
  }
}

######### DRS ######################
resource "vsphere_drs_vm_override" "drs_vm_override" {
  compute_cluster_id = "${data.vsphere_compute_cluster.cluster.id}"
  virtual_machine_id = "${vsphere_virtual_machine.vm.id}"
  drs_enabled        = false
}


##############Networking Resources ####################

############# Distributed Virtual Switch ###################

resource "vsphere_distributed_virtual_switch" "dvs" {
  name          = "terraform-test-dvs"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"

  uplinks         = ["uplink1", "uplink2", "uplink3", "uplink4"]
  active_uplinks  = ["uplink1", "uplink2"]
  standby_uplinks = ["uplink3", "uplink4"]

  host {
    host_system_id = "${data.vsphere_host.host.0.id}"
    devices        = ["${var.network_interfaces}"]
  }

  host {
    host_system_id = "${data.vsphere_host.host.1.id}"
    devices        = ["${var.network_interfaces}"]
  }

  host {
    host_system_id = "${data.vsphere_host.host.2.id}"
    devices        = ["${var.network_interfaces}"]
  }

 ############### Host virtual Switch #################
 
 resource "vsphere_host_virtual_switch" "switch" {
  name           = "vSwitchTerraformTest"
  host_system_id = "${data.vsphere_host.host.id}"

  network_adapters = ["vmnic0", "vmnic1"]

  active_nics  = ["vmnic0"]
  standby_nics = ["vmnic1"]
}



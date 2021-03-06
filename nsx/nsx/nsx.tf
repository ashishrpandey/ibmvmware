#
# Configure the VMware NSX provider to connect to the NSX
# REST API running on the NSX manager.

provider "nsxt" {
  host                  = "${var.nsx_manager}"
  username              = "${var.nsx_username}"
  password              = "${var.nsx_password}"
  allow_unverified_ssl  = true
  max_retries           = 10
  retry_min_delay       = 500
  retry_max_delay       = 5000
  retry_on_status_codes = [429]
}


# Define a NSX tag which to search for the created objects in NSX.
#
variable "nsx_tag_scope" {
  default = "projectzekeLabs"
}

variable "nsx_tag" {
  default = "zekelabs-tf-demo"
}

#
# transport zone
#
data "nsxt_transport_zone" "overlay_tz" {
  display_name = "tz1"
}

# A T0 router is used for north/south connectivity between
# the logical networking space and the physical networking space.
# Many tier 1 routers will be connected to a tier 0 router.
#
data "nsxt_logical_tier0_router" "tier0_router" {
  display_name = "DefaultT0Router"
}

# edge cluster

data "nsxt_edge_cluster" "edge_cluster1" {
  display_name = "EdgeCluster1"
}

#Create a NSX logical switch to which you can attach virtual machines.
#

resource "nsxt_logical_switch" "switch1" {
  admin_state       = "UP"
  description       = "Logical switch for zekelabs-tf-demo"
  display_name      = "TfLogicalSwitch"
  transport_zone_id = "${data.nsxt_transport_zone.overlay_tz.id}"
  replication_mode  = "MTEP"

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }

  tag {
    scope = "tenant"
    tag   = "second_example_tag"
  }
}

#
# 
# Settings to create a T1 router. In NSX a T1 router is often used on a per user, tenant,
# or application basis. Each application may have it's own T1 router. The T1
# router provides the default gateway for machines on logical switches
# connected to the T1 router.
#
resource "nsxt_logical_tier1_router" "tier1_router" {
  description                 = "Tier1 router provisioned by Terraform"
  display_name                = "TfTier1"
  failover_mode               = "PREEMPTIVE"
  high_availability_mode      = "ACTIVE_STANDBY"
  edge_cluster_id             = "${data.nsxt_edge_cluster.edge_cluster1.id}"
  enable_router_advertisement = true
  advertise_connected_routes  = true
  advertise_static_routes     = false
  advertise_nat_routes        = true

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

#
# This resource creates a logical port on the T0 router. We will connect the T1
# router to this port to enable connectivity from the tenant / application
# networks to the networks to the cloud.
#
resource "nsxt_logical_router_link_port_on_tier0" "link_port_tier0" {
  description       = "TIER0_PORT1 provisioned for zekelabs-tf-demo"
  display_name      = "TIER0_PORT1"
  logical_router_id = "${data.nsxt_logical_tier0_router.tier0_router.id}"

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

#
# Here we create a tier 1 router uplink port and connect it to T0 router port
# created above.
#
resource "nsxt_logical_router_link_port_on_tier1" "link_port_tier1" {
  description                   = "TIER1_PORT1 provisioned by Terraform"
  display_name                  = "TIER1_PORT1"
  logical_router_id             = "${nsxt_logical_tier1_router.tier1_router.id}"
  linked_logical_router_port_id = "${nsxt_logical_router_link_port_on_tier0.link_port_tier0.id}"

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

#
# Like their physical counterpart a logical switch can have switch ports. In
# this example Terraform will create a logical switch port on a logical switch.
#
resource "nsxt_logical_port" "logical_port1" {
  admin_state       = "UP"
  description       = "LP1 provisioned by Terraform"
  display_name      = "LP1"
  logical_switch_id = "${nsxt_logical_switch.switch1.id}"

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}

#
# In order to connect a logical switch to a tier 1 logical router we will need
# a downlink port on the tier 1 router and will need to  connect it to the
# switch port we created above.
#
# The IP address provided in the `ip_address` property will be default gateway
# for virtual machines connected to this logical switch.
#

resource "nsxt_logical_router_downlink_port" "downlink_port" {
  description                   = "DP1 provisioned by Terraform"
  display_name                  = "DP1"
  logical_router_id             = "${nsxt_logical_tier1_router.tier1_router.id}"
  linked_logical_switch_port_id = "${nsxt_logical_port.logical_port1.id}"
  ip_address                    = "192.168.245.1/24"

  tag {
    scope = "${var.nsx_tag_scope}"
    tag   = "${var.nsx_tag}"
  }
}


# Finally to be able to connect VMs to the newly created logical switch 
# a new vpshere_network datasource need to be defined.


data "vsphere_network" "terraform_switch1" {
    name = "${nsxt_logical_switch.switch1.display_name}"
    datacenter_id = "${data.vsphere_datacenter.dc.id}"
    depends_on = ["nsxt_logical_switch.switch1"]
}

# This terraform_switch1 should be referred in network_id inside network_interface section 
# for vsphere_virtual_machine resource.
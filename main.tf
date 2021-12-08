provider "metal" {
  auth_token = var.auth_token
}

# Provision public IPs to use for the KVM public network
resource "metal_reserved_ip_block" "routed" {
  project_id  = var.project_id
  metro       = var.metro
  type        = "public_ipv4"
  quantity    = var.public_ips_net
  description = var.ipblock_desc
}

# Create and configure the edge instance.
resource "metal_device" "edge" {
  hostname         = var.edge_hostname
  plan             = var.edge_size
  metro            = var.metro
  operating_system = var.edge_os
  billing_cycle    = var.billing_cycle
  project_id       = var.project_id
  user_data        = templatefile("build-kvm-tf.sh", { pub_ip = metal_reserved_ip_block.routed.cidr_notation })
}

# Change network mode to hybrid-unbonded for the edge instance
resource "metal_device_network_type" "edge" {
  device_id  = metal_device.edge.id
  type       = "hybrid"
  depends_on = [metal_device.edge]
}

# Assign elastic block to the edge instance
resource "metal_ip_attachment" "block_assignment" {
  device_id     = metal_device.edge.id
  cidr_notation = metal_reserved_ip_block.routed.cidr_notation
}

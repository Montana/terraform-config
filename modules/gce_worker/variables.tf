variable "env" {}
variable "index" {}
variable "instance_count" {}
variable "gce_project" {}
variable "gce_zone" {}
variable "gce_zone_suffix" {}

variable "gce_machine_type" {
  default = "n1-standard-1"
}
variable "gce_worker_image" {}

variable "cloud_init_org" {}
variable "cloud_init_com" {}

variable "subnetwork_org" {}
variable "subnetwork_com" {}
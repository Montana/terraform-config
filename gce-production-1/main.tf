variable "env" {
  default = "production"
}

variable "index" {
  default = "1"
}

variable "gce_gcloud_zone" {}
variable "gce_heroku_org" {}

variable "gce_worker_image" {
  default = "https://www.googleapis.com/compute/v1/projects/eco-emissary-99515/global/images/tfw-1516675156-0b5be43"
}

variable "github_users" {}
variable "job_board_url" {}

variable "travisci_net_external_zone_id" {
  default = "Z2RI61YP4UWSIO"
}

variable "rabbitmq_password_com" {}
variable "rabbitmq_password_org" {}
variable "rabbitmq_username_com" {}
variable "rabbitmq_username_org" {}
variable "syslog_address_com" {}
variable "syslog_address_org" {}
variable "worker_instance_count_com" {}
variable "worker_instance_count_org" {}

variable "worker_zones" {
  default = ["a", "b", "c", "f"]
}

terraform {
  backend "s3" {
    bucket         = "travis-terraform-state"
    key            = "terraform-config/gce-production-1.tfstate"
    region         = "us-east-1"
    encrypt        = "true"
    dynamodb_table = "travis-terraform-state"
  }
}

provider "google" {
  credentials = "${file("config/gce-workers-production-${var.index}.json")}"
  project     = "eco-emissary-99515"
  region      = "us-central1"
}

provider "aws" {}
provider "heroku" {}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    bucket         = "travis-terraform-state"
    key            = "terraform-config/gce-production-net-${var.index}.tfstate"
    region         = "us-east-1"
    dynamodb_table = "travis-terraform-state"
  }
}

module "rabbitmq_worker_config_com" {
  source         = "../modules/rabbitmq_user"
  admin_password = "${var.rabbitmq_password_com}"
  admin_username = "${var.rabbitmq_username_com}"
  endpoint       = "https://${trimspace(file("${path.module}/config/CLOUDAMQP_URL_HOST_COM"))}"
  scheme         = "${trimspace(file("${path.module}/config/CLOUDAMQP_URL_SCHEME_COM"))}"
  username       = "travis-worker-gce-${var.env}-${var.index}"
  vhost          = "${replace(trimspace("${file("${path.module}/config/CLOUDAMQP_URL_PATH_COM")}"), "/^//", "")}"
}

module "rabbitmq_worker_config_org" {
  source         = "../modules/rabbitmq_user"
  admin_password = "${var.rabbitmq_password_org}"
  admin_username = "${var.rabbitmq_username_org}"
  endpoint       = "https://${trimspace(file("${path.module}/config/CLOUDAMQP_URL_HOST_ORG"))}"
  scheme         = "${trimspace(file("${path.module}/config/CLOUDAMQP_URL_SCHEME_ORG"))}"
  username       = "travis-worker-gce-${var.env}-${var.index}"
  vhost          = "${replace(trimspace("${file("${path.module}/config/CLOUDAMQP_URL_PATH_ORG")}"), "/^//", "")}"
}

data "template_file" "worker_config_com" {
  template = <<EOF
### worker.env
${file("${path.module}/worker.env")}
### config/worker-com.env
${file("${path.module}/config/worker-com.env")}

export TRAVIS_WORKER_AMQP_URI=${module.rabbitmq_worker_config_com.uri}
export TRAVIS_WORKER_GCE_SUBNETWORK=jobs-com
export TRAVIS_WORKER_HARD_TIMEOUT=120m
export TRAVIS_WORKER_TRAVIS_SITE=com
EOF
}

data "template_file" "worker_config_org" {
  template = <<EOF
### worker.env
${file("${path.module}/worker.env")}
### config/worker-org.env
${file("${path.module}/config/worker-org.env")}

export TRAVIS_WORKER_AMQP_URI=${module.rabbitmq_worker_config_org.uri}
export TRAVIS_WORKER_GCE_SUBNETWORK=jobs-org
export TRAVIS_WORKER_TRAVIS_SITE=org
EOF
}

module "gce_worker_group" {
  source = "../modules/gce_worker_group"

  env                           = "${var.env}"
  gcloud_cleanup_account_json   = "${file("${path.module}/config/gce-cleanup-production-${var.index}.json")}"
  gcloud_cleanup_job_board_url  = "${var.job_board_url}"
  gcloud_zone                   = "${var.gce_gcloud_zone}"
  github_users                  = "${var.github_users}"
  heroku_org                    = "${var.gce_heroku_org}"
  index                         = "1"
  project                       = "eco-emissary-99515"
  region                        = "us-central1"
  syslog_address_com            = "${var.syslog_address_com}"
  syslog_address_org            = "${var.syslog_address_org}"
  travisci_net_external_zone_id = "${var.travisci_net_external_zone_id}"
  worker_account_json_com       = "${file("${path.module}/config/gce-workers-production-${var.index}.json")}"
  worker_account_json_org       = "${file("${path.module}/config/gce-workers-production-${var.index}.json")}"
  worker_config_com             = "${data.template_file.worker_config_com.rendered}"
  worker_config_org             = "${data.template_file.worker_config_org.rendered}"
  worker_image                  = "${var.gce_worker_image}"
  worker_instance_count_com     = "${var.worker_instance_count_com}"
  worker_instance_count_org     = "${var.worker_instance_count_org}"
  worker_subnetwork             = "${data.terraform_remote_state.vpc.gce_subnetwork_workers}"
  worker_zones                  = "${var.worker_zones}"
}

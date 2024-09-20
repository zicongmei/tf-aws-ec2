# This code is compatible with Terraform 4.25.0 and versions that are backwards compatible to 4.25.0.
# For information about validating this Terraform code, see https://developer.hashicorp.com/terraform/tutorials/gcp-get-started/google-cloud-platform-build#format-and-validate-the-configuration
data "google_project" "project" {}

provider "google" {
  project     = var.gcp_project_id
  region      = var.gcp_region
  zone        = var.gcp_zone
}

resource "google_compute_instance" "my_instance" {
  boot_disk {
    auto_delete = true
    device_name = var.name

    initialize_params {
      image = "projects/ml-images/global/images/c0-deeplearning-common-cu123-v20240730-debian-11-py310"
      size  = 300
      type  = "pd-balanced"
    }

    mode = "READ_WRITE"
  }

  can_ip_forward      = false
  deletion_protection = false
  enable_display      = false

  guest_accelerator {
    count = 2
    type  = "${data.google_project.project.id}/zones/${var.gcp_zone}/acceleratorTypes/nvidia-tesla-t4"
  }

  labels = {
    goog-ec-src = "vm_add-tf"
  }

  machine_type = "n1-highmem-4"

  metadata = {
    enable-oslogin = "true"
  }

  name = var.name

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    queue_count = 0
    stack_type  = "IPV4_ONLY"
    subnetwork  = "${data.google_project.project.id}/regions/${var.gcp_region}/subnetworks/default"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "TERMINATE"
    preemptible         = true
    provisioning_model  = "SPOT"
  }

  service_account {
    email  = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  tags = ["https-server"]
  zone = "${var.gcp_zone}"

  metadata_startup_script = local.startup
}

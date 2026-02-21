variable "project" {
  description = "this is gcp project-id"
  type        = string
  default     = "project-876aa341-49d2-4a26-aaf"
}

variable "region" {
  description = "this is gcp region"
  type        = string
  default     = "us-central1"
}

variable "K8s_version" {
  description = "this is the gke version"
  type        = string
  default     = "1.31.6-gke.1020000"
}

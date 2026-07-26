variable "environment" {
  description = "Deployment environment, used in resource names."
  type        = string
}

variable "region" {
  description = "AWS region the cluster runs in."
  type        = string
}

variable "ami_id" {
  description = "AMI id (arm64 Amazon Linux 2023) used for all cluster nodes."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for cluster resource names."
  type        = string
  default     = "starrocks"
}

variable "cluster_suffix" {
  description = "Suffix distinguishing parallel cluster generations."
  type        = string
}

variable "network" {
  description = "VPC CIDR and subnet placement for the cluster nodes."
  type = object({
    vpc_cidr   = string
    subnet_ids = list(string)
  })
}

variable "security_group_id" {
  description = "Security group attached to every node network interface."
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name assumed by every node."
  type        = string
}

variable "key_pair_name" {
  description = "EC2 key pair name granting SSH access to the nodes."
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the FE query target group the frontends register into."
  type        = string
}

variable "fe_meta_volume_ids" {
  description = "EBS volume ids for the FE metadata disks, keyed by frontend node id."
  type        = map(string)
}

variable "ssl" {
  description = "TLS server material used by the FE for its secure query endpoint."
  type = object({
    cert              = string
    key               = string
    keystore_password = string
  })
  sensitive = true
}

variable "secrets" {
  description = "Names of the Secrets Manager secrets the nodes read at boot."
  type = object({
    root_name = string
  })
}

variable "s3_shared_data" {
  description = "Shared-data S3 storage backing the cluster."
  type = object({
    bucket = string
    prefix = string
    region = string
  })
}

variable "frontends" {
  description = "StarRocks frontend nodes keyed by node id (e.g. fe-1); set `release` per node for a one-node-at-a-time upgrade, or bump `generation` to reprovision a node whose change lives only in user_data."
  type = map(object({
    instance_type   = optional(string, "c6g.xlarge")
    release         = optional(string)
    leader          = optional(bool, false)
    initial_cluster = optional(bool, false)
    generation      = optional(number, 0)
    root_gb         = optional(number, 30)
    meta_gb         = optional(number, 50)
  }))

  validation {
    condition     = alltrue([for k in keys(var.frontends) : can(regex("^[a-z]+-[0-9]+$", k))])
    error_message = "Frontend node keys must look like fe-1, fe-2 (letters, dash, trailing number)."
  }
}

variable "compute_nodes" {
  description = "StarRocks compute nodes keyed by node id (e.g. cn-1); set `release` per node for a one-node-at-a-time upgrade, or bump `generation` to reprovision a node whose change lives only in user_data."
  type = map(object({
    instance_type = optional(string, "r8gd.2xlarge")
    release       = optional(string)
    generation    = optional(number, 0)
    root_gb       = optional(number, 30)
    mem_limit     = optional(string, "80%")
  }))

  validation {
    condition     = alltrue([for k in keys(var.compute_nodes) : can(regex("^[a-z]+-[0-9]+$", k))])
    error_message = "Compute node keys must look like cn-1, cn-2 (letters, dash, trailing number)."
  }
}

variable "starrocks" {
  description = "Cluster-wide StarRocks defaults: fallback release (overridable per node via `frontends`/`compute_nodes` `release`), binary download source, and node CPU architecture."
  type = object({
    default_release   = string
    download_base_url = string
    arch              = optional(string, "arm64")
  })
}

variable "ranger" {
  description = "Apache Ranger integration credentials for the FE."
  type = object({
    host          = string
    sync_username = string
    sync_password = string
  })
}

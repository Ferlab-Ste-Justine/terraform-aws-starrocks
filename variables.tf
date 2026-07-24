variable "environment" {
  description = "Deployment environment, used in resource and secret names."
  type        = string
}

variable "region" {
  description = "AWS region the cluster runs in."
  type        = string
}

variable "account_id" {
  description = "AWS account id, used to name the shared-data bucket."
  type        = string
}

variable "ami_id" {
  description = "AMI id (arm64 Amazon Linux 2023) used for all cluster nodes."
  type        = string
}

variable "domain_name" {
  description = "Base domain used for the cluster server certificate SAN."
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
  description = "VPC and subnet placement for the cluster nodes and NLB."
  type = object({
    vpc_id     = string
    vpc_cidr   = string
    subnet_ids = list(string)
  })
}

variable "frontends" {
  description = "StarRocks frontend nodes keyed by node id (e.g. fe-1); set `release` per node to override `starrocks.default_release` for a one-node-at-a-time upgrade."
  type = map(object({
    instance_type = optional(string, "c6g.xlarge")
    release       = optional(string)
    leader        = optional(bool, false)
    root_gb       = optional(number, 30)
    meta_gb       = optional(number, 50)
  }))

  validation {
    condition     = alltrue([for k in keys(var.frontends) : can(regex("^[a-z]+-[0-9]+$", k))])
    error_message = "Frontend node keys must look like fe-1, fe-2 (letters, dash, trailing number)."
  }
}

variable "compute_nodes" {
  description = "StarRocks compute nodes keyed by node id (e.g. cn-1); set `release` per node to override `starrocks.default_release` for a one-node-at-a-time upgrade."
  type = map(object({
    instance_type = optional(string, "r8gd.2xlarge")
    release       = optional(string)
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

variable "iam" {
  description = "Extra IAM policy ARNs attached to the node role, keyed by a stable name."
  type = object({
    additional_policies = optional(map(string), {})
  })
  default = {}
}

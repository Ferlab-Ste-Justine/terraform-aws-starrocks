# terraform-aws-starrocks

Cluster-level StarRocks deployment on AWS EC2: frontends (FE) and compute nodes (CN),
internal NLB, node IAM role, shared-data S3 bucket, TLS material and Secrets Manager
secrets. The module composes the shared cloud-init template
`terraform-cloudinit-templates//starrocks` and renders one independent config per node.

The orchestration (VPC, subnets, AMI, caller identity, datalake/nextflow IAM policies)
stays in the caller; the module receives them as inputs.

## Usage

```hcl
module "starrocks" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-aws-starrocks.git//?ref=v0.1.5"

  environment = "qa"
  region      = "ca-central-1"
  account_id  = data.aws_caller_identity.current.account_id
  ami_id      = "ami-0ad01c5e1e4a286e5"
  domain_name = "dev.qlin.aws.sante.quebec"

  network = {
    vpc_id     = data.aws_vpc.qlin_qa.id
    vpc_cidr   = data.aws_vpc.qlin_qa.cidr_block
    subnet_ids = data.aws_subnets.workload_az.ids
  }

  frontends = {
    "fe-1" = { leader = true }
    "fe-2" = {}
    "fe-3" = {}
  }

  compute_nodes = {
    "cn-1" = {}
    "cn-2" = {}
    "cn-3" = {}
  }

  starrocks = {
    default_release   = "3.5.18"
    download_base_url = "https://starrocks-binaries.dev.qlin.aws.sante.quebec/starrocks"
    arch              = "arm64"
  }

  ranger = {
    host          = "https://ranger.dev.qlin.aws.sante.quebec"
    sync_username = "rangerusersync"
    sync_password = data.aws_secretsmanager_secret_version.ranger_sync.secret_string
  }

  iam = {
    additional_policies = {
      iceberg_datalake = aws_iam_policy.iceberg_datalake.arn
      nextflow_output  = aws_iam_policy.nextflow_output.arn
    }
  }
}
```

## Per-node declarative config

Each node is one entry in `frontends` / `compute_nodes`, keyed by node id (`fe-1`, `cn-2`, ...).
The trailing number in the key sets both the node name suffix and the subnet index into
`network.subnet_ids` (provide that list in a stable order). Every node is independent, which
is what enables a one-node-at-a-time rollout:

- Upgrade one node: set its `release`, e.g. `"fe-2" = { release = "4.0.11" }`. The tarball URL
  change drives a `replace_triggered_by` recreation of that node only.
- Move the leader: set `leader = true` on the target FE (exactly one FE must be leader).
- Resize a node: edit its `instance_type` (or `root_gb` / `meta_gb` / `mem_limit`).

`release` left unset falls back to `starrocks.default_release`.

## Open items

- CN nodes render cloud-init from `//starrocks?ref=v0.52.2` while FE uses `v0.54.1`. Align CN
  to v0.54.1 once its rendered output is validated (changing the ref changes the boot config,
  so it is a per-node reprovision, not an in-place edit).

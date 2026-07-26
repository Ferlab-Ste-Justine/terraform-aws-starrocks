# terraform-aws-starrocks

Compute layer of a StarRocks cluster on AWS EC2: frontend (FE) and compute (CN) nodes,
their network interfaces, FE metadata volume attachments, FE target-group registrations and
per-node cloud-init. The module composes the shared cloud-init template
`terraform-cloudinit-templates//starrocks` and renders one independent config per node.

The persistent and shared resources live in the caller and are passed in by identifier: the
security group, IAM instance profile, key pair, NLB target group, shared-data S3 bucket, FE
metadata EBS volumes, TLS server material and the Secrets Manager secrets. This is the same
split the libvirt platforms use (volumes, networking and security groups declared by the
orchestration, connected to the compute module by id).

## Usage

```hcl
module "starrocks" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-aws-starrocks.git//?ref=v0.2.0"

  environment    = "qa"
  region         = "ca-central-1"
  ami_id         = "ami-0ad01c5e1e4a286e5"
  name_prefix    = "starrocks"
  cluster_suffix = "v2"

  network = {
    vpc_id     = data.aws_vpc.qlin_qa.id
    vpc_cidr   = data.aws_vpc.qlin_qa.cidr_block
    subnet_ids = data.aws_subnets.workload_az.ids
  }

  security_group_id    = aws_security_group.node.id
  iam_instance_profile = aws_iam_instance_profile.node.name
  key_pair_name        = aws_key_pair.starrocks.key_name
  target_group_arn     = aws_lb_target_group.fe_query.arn
  fe_meta_volume_ids   = { for k, v in aws_ebs_volume.fe_meta : k => v.id }

  ssl = {
    cert              = tls_locally_signed_cert.starrocks_ssl_server.cert_pem
    key               = tls_private_key.starrocks_ssl_server.private_key_pem
    keystore_password = random_password.starrocks_ssl_keystore.result
  }

  secrets = {
    root_name = aws_secretsmanager_secret.starrocks_root.name
  }

  s3_shared_data = {
    bucket = aws_s3_bucket.starrocks.id
    prefix = "v2"
    region = "ca-central-1"
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
}
```

## Per-node declarative config

Each node is one entry in `frontends` / `compute_nodes`, keyed by node id (`fe-1`, `cn-2`, ...).
The trailing number in the key sets both the node name suffix and the subnet index into
`network.subnet_ids` (provide that list in a stable order). Every node is independent, which
is what enables a one-node-at-a-time rollout:

- Upgrade one node: set its `release`, e.g. `"fe-2" = { release = "4.0.11" }`. The tarball URL
  change drives a `replace_triggered_by` recreation of that node only.
- Reprovision one node without a version change: bump its `generation`, e.g.
  `"fe-2" = { release = "4.0.11", generation = 1 }`. Use this to roll a change that lives only in
  the node's user_data (mount logic, boot guard, config) — those are masked by
  `ignore_changes = [user_data]`, so a version-less `release` edit alone would not recreate anything.
- Move the leader: set `leader = true` on the target FE (exactly one FE must be leader).
- Resize a node: edit its `instance_type` (or `root_gb` / `mem_limit`). FE metadata volume size
  (`meta_gb`) is owned by the caller.

`release` left unset falls back to `starrocks.default_release`.

`generation` is a monotonic counter: only ever increase it, one node at a time. It defaults to `0`,
which produces the exact same replace trigger as omitting it — so adding the field to an existing
cluster is a no-op. Never decrement or reset a bumped `generation` back to `0`: that changes the
trigger back and reprovisions the node unexpectedly. The value is sticky by design.

# Writing Terraform: details and examples

Companion to the `terraform-conventions` skill. Read the section you need.

## Module file layout

```
modules/storage/            # reusable (child) module
├── README.md
├── main.tf                 # resources; module calls go here too
├── iam.tf                  # optional split once a concern passes ~150 lines
├── variables.tf            # alphabetical
├── outputs.tf              # alphabetical
├── versions.tf             # terraform { required_version, required_providers }
├── locals.tf               # only if locals are shared across files
├── templates/policy.json.tftpl
├── tests/defaults.tftest.hcl
└── examples/basic/         # a runnable root module that calls this one
```

Root modules add `providers.tf` and `backend.tf`, and keep non-secret inputs in `terraform.tfvars`.

`.gitignore`: `.terraform/`, `*.tfstate`, `*.tfstate.*`, `.terraform.tfstate.lock.info`, plan files (`*.tfplan`, `tfplan*`), `crash.log`, and any `.tfvars` holding secrets. Commit `.terraform.lock.hcl`.

## Block layout

```hcl
resource "aws_instance" "web" {
  for_each = var.web_instances                  # meta-arguments first

  ami           = data.aws_ami.base.id          # then arguments, aligned '='
  instance_type = each.value.instance_type
  subnet_id     = each.value.subnet_id

  root_block_device {                           # then nested blocks
    volume_size = each.value.root_volume_size_gib
  }

  tags = merge(var.tags, { Name = "web-${each.key}" })

  lifecycle {                                   # then lifecycle
    ignore_changes = [ami]                      # AMI rolls via the ASG, not here
  }
}
```

## Variables

```hcl
variable "database" {
  type = object({
    instance_class        = string
    allocated_storage_gib = optional(number, 20)
    multi_az              = optional(bool, false)
    backup_retention_days = optional(number, 7)
  })
  description = "Database sizing and resilience settings."

  validation {
    condition     = var.database.backup_retention_days >= 1
    error_message = "backup_retention_days must be at least 1."
  }
}

variable "admin_password" {
  type        = string
  description = "Initial admin password. Passed from the pipeline's secret store."
  sensitive   = true
  ephemeral   = true   # Terraform/OpenTofu >= 1.11 with a write-only argument
}
```

- Use `nullable = false` for required-ish inputs where `null` makes no sense.
- Don't use empty-string or empty-list defaults unless empty is a valid choice the API accepts.
- A literal reused in several places is a `local`, not a variable.

## Outputs

```hcl
output "bucket_arn" {
  description = "ARN of the artifacts bucket."
  value       = aws_s3_bucket.this.arn   # the attribute, not var.bucket_name
}
```

Mark outputs `sensitive = true` when they carry secrets. Root outputs are the contract other stacks read; treat renames as breaking.

## Iteration and conditionals

```hcl
# Good: stable keys; removing "b" doesn't shift "c".
resource "aws_subnet" "private" {
  for_each          = var.private_subnets     # map(object({ cidr, az }))
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
}

# Good: 0/1 toggle on an explicit flag, not on a resource attribute.
resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "/vpc/${var.name}/flow-logs"
}
```

Avoid `count` over lists of distinct things: removing an element shifts indexes and replaces everything after it. Reference toggled resources with `one(aws_x.this[*].id)`.

## Expressions

- Split long expressions into named `locals`; one idea per local.
- No nested ternaries. Use a lookup map (`local.sizes[var.environment]`) instead.
- `dynamic` blocks only when the number of nested blocks is driven by input; otherwise write them out.
- Use `try()`/`can()` sparingly and never to hide real errors.
- Long documents (policies, cloud-init) go in `templates/*.tftpl` with `templatefile()` or are built with `jsonencode()` / `aws_iam_policy_document`, not heredoc strings.

## Dependencies

```hcl
# Implicit dependency through a computed attribute.
resource "google_project_iam_member" "app" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Hidden dependency: explain it.
resource "aws_instance" "app" {
  # ...
  # The bootstrap script reads the parameter at boot; nothing references it.
  depends_on = [aws_ssm_parameter.app_config]
}
```

`depends_on` on a module makes every data source inside it deferred to apply, so avoid it on module blocks.

## Refactoring without destroying

```hcl
moved {
  from = aws_s3_bucket.bucket
  to   = aws_s3_bucket.artifacts
}

moved {
  from = aws_vpc.main
  to   = module.network.aws_vpc.this
}

import {
  to = aws_route53_zone.primary
  id = "Z0123456789ABCDEFGHIJ"
}

removed {
  from = aws_instance.legacy
  lifecycle {
    destroy = false   # stop managing it, keep the real object
  }
}
```

Keep `moved` blocks in shared modules for at least one major version so callers can upgrade. `import` and `removed` take effect at apply, which CI runs.

## Guarding assumptions

```hcl
resource "aws_db_instance" "this" {
  # ...
  deletion_protection = true

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = var.database.multi_az || var.environment != "prod"
      error_message = "Production databases must be multi-AZ."
    }
  }
}

check "site_health" {
  data "http" "site" {
    url = "https://${aws_route53_record.site.fqdn}/health"
  }

  assert {
    condition     = data.http.site.status_code == 200
    error_message = "Site health check did not return 200."
  }
}
```

Preconditions/postconditions fail the plan or apply; `check` blocks only warn.

## Secrets

Order of preference:
1. Don't let Terraform see the secret: have the service generate and store it (e.g. `manage_master_user_password = true` on RDS), and grant access to it.
2. Ephemeral values (Terraform / OpenTofu >= 1.11): read with an `ephemeral` resource (e.g. `ephemeral "aws_secretsmanager_secret_version"`) or an `ephemeral` variable, and pass it to a write-only argument (`password_wo` + `password_wo_version`). Nothing lands in state or plan.
3. A data source or variable marked `sensitive`: hidden in CLI output, but stored in plaintext in state. Only acceptable because state is encrypted and access-controlled (OpenTofu can also encrypt state client-side).

Never put secrets in `default`, committed `.tfvars`, `locals`, or outputs without `sensitive = true`.

## Tests

```hcl
# tests/defaults.tftest.hcl
mock_provider "aws" {}

variables {
  name = "test"
}

run "bucket_is_private" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls
    error_message = "Bucket must block public ACLs."
  }
}

run "rejects_bad_retention" {
  command = plan
  variables {
    database = { instance_class = "db.t4g.micro", backup_retention_days = 0 }
  }
  expect_failures = [var.database]
}
```

Run with `terraform test` / `tofu test`. Plan-only tests with mocked providers need no credentials, so they run in the session and in CI. Integration tests that create real resources run only in CI in an isolated account/project, with unique names (`random_id`) and cleanup.

## Static checks

`fmt` and `tflint` run on each edit, `validate` (and `trivy` config scan, or the repo's `mise run lint`) on Stop. Fix findings rather than silencing them; a `# tflint-ignore:` or `# trivy:ignore:` needs a comment saying why.

## Sources

- HashiCorp style guide: https://developer.hashicorp.com/terraform/language/style
- Google Cloud Terraform best practices: https://docs.cloud.google.com/docs/terraform/best-practices/general-style-structure (and the reusable-modules, root-modules, dependency-management, security and testing pages)
- AWS Prescriptive Guidance, Terraform AWS provider best practices: https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html
- Ephemeral values / write-only arguments: https://developer.hashicorp.com/terraform/language/manage-sensitive-data/write-only, https://opentofu.org/docs/v1.11/language/ephemerality/

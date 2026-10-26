---
name: terraform-conventions
description: Jig conventions for writing Terraform/OpenTofu code (layout, naming, variables, outputs, expressions, dependencies, providers, versions, secrets, safety, tests). Loaded automatically when working on .tf/.tfvars files.
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/*.tofu"
  - "**/*.tftest.hcl"
user-invocable: false
---

# Terraform / OpenTofu conventions (Jig)

Company-wide defaults, based on the Google Cloud Terraform best practices, the HashiCorp style guide and the AWS Terraform guides; where they differ, Google's wins unless a rule below says otherwise. A repo's own `.claude/rules/terraform.md` or ADRs in `.archgate/adrs/` override them. Details, examples and rationale: [writing.md](writing.md). For how to split code into modules, stacks and environments, use the `terraform-architecture` skill.

**Binary.** Use `tofu` if the repo has `.opentofu-version` or pins `opentofu` in `mise.toml`, otherwise `terraform`. Never run `apply`, `destroy`, `import` or `state` mutations: CI applies (the guard blocks them). Validate offline: `init -backend=false`, then `validate`. The Stop hook does this for modules you edited; the edit hook runs `fmt` and `tflint`.

**Layout.**
- One module per directory: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` (`required_version`, `required_providers`); `providers.tf`/`backend.tf` in root modules only; `locals.tf`/`data.tf` when large.
- Split `main.tf` by concern (`network.tf`, `iam.tf`) past ~150 lines, never one file per resource.
- Module root holds only `*.tf` and `README.md`/`CHANGELOG.md`; extra docs in `docs/`.
- Submodules in `modules/<name>/`; examples in `examples/<name>/` (one directory each, with a `README.md`); templates `templates/*.tftpl`; static files and long heredocs in `files/` (load with `file()`); scripts Terraform calls in `scripts/`, others in `helpers/` (documented, validate arguments, support `--help`).
- Every module has a `README.md` (inputs/outputs from terraform-docs if the repo uses it). Shared modules have a `CODEOWNERS`; PRs need owner approval.

**Naming.** snake_case for every block label, variable, output and local. Names are singular nouns describing the role, never repeating the type (`aws_s3_bucket.artifacts`, not `aws_s3_bucket.s3_bucket_artifacts`). Name the only resource of its type `main` (`this` is accepted where a repo already uses it); use meaningful names (`primary`, `secondary`) to tell same-type resources apart. Underscores in object names; argument values such as `name` may use hyphens. Numeric inputs, locals and outputs carry units (`disk_size_gib`, `timeout_seconds`); storage units use binary prefixes (gibi), others decimal; booleans are positive (`enable_logging`, not `disable_logging`).

**Block order.** Meta-arguments first (`count`/`for_each`, `provider`), then arguments, then nested blocks, then `lifecycle`, then `depends_on`, separated by blank lines. Data sources sit next to the resources that use them (or in `data.tf`). Comments use `#`.

**Variables.** Every variable has `type` and `description`; order `type`, `description`, `default`, `sensitive`, `nullable`, `validation`. Defaults only for environment-independent values; environment-specific ones (account, project, CIDRs) have none. Expose a variable only for a concrete need to vary it: adding one with a default is backward compatible, removing one is breaking. Group related settings in an `object({...})` with `optional()` attributes rather than many loose variables. Use `validation` for constrained inputs. Secrets: `sensitive = true`, never a default.

**Outputs.** Every output has a `description`. Output resource attributes, never pass input variables straight through (that breaks the dependency graph). Reusable modules expose at least one output per resource (ids/ARNs) so callers can depend on them.

**Expressions.** Keep them readable: name intermediate values in `locals`, at most one ternary per line, `dynamic` blocks only when the block count really varies. Use `locals` sparingly for repeated literals, not as a second variable layer. Prefer attachment resources (`aws_security_group_rule`, `aws_iam_role_policy_attachment`) over inline blocks when both exist, and don't mix the two for the same object.

**Iteration.** `for_each` over maps/sets with stable, meaningful keys for multiple instances; `count` only for 0/1 toggles (`count = var.enable_x ? 1 : 0`). Drive a toggle from an explicit `enable_x` variable, not from a resource attribute unknown until apply ("count cannot be computed"); same for `for_each` keys.

**Dependencies.** Rely on implicit dependencies by referencing attributes (prefer computed ones like `id`/`arn` over inputs like `name`). `depends_on` only as a last resort for hidden dependencies, with a comment saying why.

**Providers and versions.**
- Child modules never configure providers or backends; they declare `required_providers` with minimum versions (`>=`).
- Root modules declare each provider, pin `required_version`, pin providers to a minor with `~>` (`~> 5.1.0`) in `versions.tf`, and commit `.terraform.lock.hcl`.
- Root inputs come from `terraform.tfvars` only: no `-var` or alternative var-files.
- Pin module sources to a release tag or registry version (commit SHA for third-party git modules), never a branch; constrain the major for shared modules (`~> 20.0`).
- Set common tags/labels once (e.g. AWS `default_tags` in the root provider); modules expose a `tags`/`labels` map (default `{}`).
- Shared modules release with SemVer.

**Google Cloud.** Enable APIs with `google_project_service` (or the `project_services` module); a module that does exposes `enable_apis` (default `true`) and sets `disable_services_on_destroy = false`. Never use service account keys: CI uses the pipeline's identity (workload identity federation outside Google Cloud), local runs use `gcloud auth application-default login`.

**Secrets.** Never hardcode secrets or commit `.tfvars` that hold them. Read them at apply time from a secrets manager; on Terraform ≥ 1.11 / OpenTofu ≥ 1.11 prefer ephemeral resources and write-only arguments (`*_wo`) so they never reach state or plan. Avoid resources that store key material or secrets in state (`tls_private_key`, `google_service_account_key`, `vault_generic_secret`, `google_client_config`) unless there is no alternative. Remember `sensitive` only hides values in output; state still holds them.

**Safety.**
- Stateful resources (databases, buckets, KMS keys, DNS zones) get `lifecycle { prevent_destroy = true }` and the provider's deletion protection in production roots.
- Renames and moves into modules use `moved` blocks; dropping from management uses `removed` blocks, never state commands.
- Avoid import: create in Terraform and delete the old resource; use an `import` block only with explicit approval when recreating is costly, then manage it only through Terraform.
- No `0.0.0.0/0` ingress, public buckets, or wildcard IAM actions/resources without a comment saying why.
- Use `check` blocks or `precondition`/`postcondition` for assumptions a plan should verify.
- Avoid provisioners, `local-exec` and scripts (untracked state); if unavoidable, document why and a deprecation plan.

**Tests.**
- Test each module on its own, cheapest first: static (`fmt`, `validate`, tflint); plan-only `terraform test` / `tofu test` (`tests/*.tftest.hcl`, `command = plan`, mocked providers; sessions have no cloud credentials); integration in CI.
- Tests never share state.

**Enforced rules (ADRs).** `archgate check` and tflint hold the line mechanically; read the ADR before arguing with a failure (`archgate adr show <ID>`). TF-001 pin module sources; TF-002 no `provider`/`backend` blocks in child modules (under `modules/`); TF-003 the shared `.tflint.hcl` (naming, documented/typed variables and outputs, standard module files); TF-006 root modules commit `.terraform.lock.hcl`; TF-007 stateful resources in production roots set `prevent_destroy = true`; TF-009 no secret values in `.tfvars`/`.tf`, secret-named variables are `sensitive` with no default. A justified exception is `# archgate-ignore TF-00X/<rule-id> <reason>` on the line before the flagged line (the block start for TF-002/006/007, the variable block or the line for TF-009); the reason is required.

**Finding things.** Use the LSP (go to definition/references on `module.x`, `var.y`) before grepping. Use registry docs (terraform MCP server, if enabled) for provider arguments instead of guessing.

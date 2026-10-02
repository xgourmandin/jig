---
name: terraform-architecture
description: How to structure Terraform/OpenTofu infrastructure - module types and boundaries, splitting state into stacks, environments, cross-stack data, module versioning and repo layout. Use when designing new infrastructure, adding a module or environment, deciding where code or state belongs, or refactoring a large Terraform codebase.
---

# Terraform / OpenTofu architecture (Jig)

Company-wide defaults, based on the HashiCorp, Google Cloud and AWS best-practice guides and terraform-best-practices.com. A repo's ADRs in `.archgate/adrs/` override them; check them first (`adrs` skill). Line-level style is in the `terraform-conventions` skill. Rules that are checked mechanically: TF-002 (no providers/backends in child modules), TF-006 (root modules commit the lock file), TF-007 (`prevent_destroy` on stateful production resources).

## Three levels of code

| Level                             | What it is                                                                         | Configures providers/backend? | Example                                                   |
| --------------------------------- | ---------------------------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------- |
| **Resource module** (child)       | A small set of resources that together deliver one capability                      | No                            | `modules/network`: VPC, subnets, NAT, routes              |
| **Service/infrastructure module** | Composes resource modules for one system in one boundary (account/project, region) | No                            | `modules/payments-platform`: network + database + cluster |
| **Root module (stack)**           | What `init`/`plan` run in; one state file per stack per environment                | Yes                           | `live/prod/eu-west-1/network`                             |

Rules:

- A module is a new abstraction. Don't wrap a single resource: if you can't name the module differently from the resource type inside it, use the resource directly.
- Group by capability and change together (network foundation, data tier, IAM baseline, an application), not by resource type.
- Keep the module tree flat: at most one or two levels of nesting. Prefer the root module composing sibling modules and wiring outputs into inputs over modules calling modules calling modules.
- Hard-code sensible, environment-independent choices inside modules; expose only what really varies per caller or environment.

## Splitting state (stacks)

Everything in one state is planned, refreshed, locked and put at risk together. Split into several root modules when:

- it grows beyond roughly 100 resources (Google suggests a few dozen), or plans get slow;
- parts change at different rates (network and IAM rarely; applications often);
- parts have different owners, blast radius or permissions (who can change prod networking vs. an app);
- parts live in different accounts/projects or regions.

Typical layering, each its own state, lower layers never read higher ones:

1. **Bootstrap**: state backend, CI identities (applied rarely, by a platform admin).
2. **Foundation**: accounts/projects, org policies, IAM baseline, DNS zones.
3. **Network**: VPCs, subnets, peering/transit, shared endpoints.
4. **Shared services**: clusters, databases, queues, registries.
5. **Applications**: one stack per service, owned by its team.

Don't split so fine that a single change needs coordinated applies across many stacks; that's the sign two stacks belong together.

## Environments

- One directory per environment (and region) with its own backend and state, all calling the same versioned modules: `live/<env>/<region>/<stack>/`. Differences between environments are only in inputs (`terraform.tfvars`), never copy-pasted resources.
- Don't use CLI workspaces to separate environments: they share one backend and credentials, and it's easy to apply to the wrong one. Keep each environment directory on the default workspace.
- Separate backends (bucket/prefix and access policy) per environment, ideally separate cloud accounts/projects. Production state is writable only by the CI pipeline and break-glass roles.
- Promote changes by bumping the module version per environment (dev, then staging, then prod), not by editing prod first.
- If the repo uses a wrapper (Terragrunt, Terramate, HCP Terraform workspaces/Stacks), follow its conventions instead of inventing a directory scheme.

## Sharing data between stacks

Prefer, in order:

1. **Provider data sources** that look up the real object by name or tag (`data "aws_vpc"`, `data "google_compute_network"`). No coupling to another stack's state.
2. **A published value** written by the producing stack to a parameter store/registry (`aws_ssm_parameter`, Consul, HCP `tfe_outputs`).
3. **`terraform_remote_state`**, read-only and only for outputs meant as a contract. It needs read access to the whole other state (including its secrets), so use it sparingly and never across trust boundaries.

Never copy IDs as literals between stacks.

## State and backend

- Remote backend with locking, versioning and encryption at rest (S3 with `use_lockfile = true` instead of DynamoDB locking on Terraform >= 1.10; GCS; azurerm; HCP Terraform). OpenTofu repos can add client-side state encryption.
- One state key per stack per environment, derived from the directory path, so keys never collide.
- State holds every attribute in plaintext: treat state read access as secret access.
- No local state files, and no hand-editing state: use `moved`/`import`/`removed` blocks, applied by CI.

## Module versioning and sources

- Local path (`./modules/x`) for modules used only inside this repo.
- Modules shared across repos live in their own repo named `terraform-<provider>-<name>` (or a module monorepo with per-module tags) and are released with SemVer tags; consumers pin a version (`~> 2.1` for registry modules, `?ref=v2.1.0` for git).
- Third-party modules: pin an exact version or commit SHA, review before upgrading, and prefer well-maintained ones (terraform-aws-modules, terraform-google-modules) over writing your own.
- A shared module's `README.md`, `examples/` and `tests/` are its contract; removing a variable, renaming an output or forcing replacement is a major version bump, with `moved` blocks where possible.

## Repo layout (one common shape)

```
infra/
├── modules/                    # repo-local modules (or pulled from a module registry)
│   ├── network/
│   └── service/
└── live/
    ├── dev/eu-west-1/
    │   ├── network/            # root: backend.tf, providers.tf, main.tf, terraform.tfvars
    │   └── payments/
    └── prod/eu-west-1/
        ├── network/
        └── payments/
```

Code and CI pipelines map one-to-one to root modules: a PR plans only the stacks whose directory (or module dependency) changed.

## Delivery

- Every change goes through a PR: CI runs fmt, validate, tflint, a security scan (trivy/checkov), tests, and a plan per affected stack posted on the PR. Humans review the plan (see the `tf-plan-review` skill); CI applies after merge, from `main`.
- Policies as code (OPA/Conftest, Sentinel, trivy custom checks) enforce tagging, sizing and security rules consistently.
- Run drift detection (scheduled plan) on long-lived stacks; fix drift in code, not in the console.

## When proposing a design

State: the stacks (root modules) and what each owns, the modules they call (new or existing, with versions), how data flows between stacks, per-environment differences, and the blast radius of the riskiest change. If it sets a lasting rule (new layer, new wrapper tool, state split), propose an ADR.

## Sources

- HashiCorp style guide (repo structure, environments, state sharing): https://developer.hashicorp.com/terraform/language/style
- Google Cloud root modules and reusable modules: https://docs.cloud.google.com/docs/terraform/best-practices/root-modules, https://docs.cloud.google.com/docs/terraform/best-practices/reusable-modules
- AWS Prescriptive Guidance (structure, backends): https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html, https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html
- terraform-best-practices.com key concepts (resource module, infrastructure module, composition): https://www.terraform-best-practices.com/key-concepts

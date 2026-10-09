# Working on SRE Landing Zone

Explain and reproduce a multi-account operations design from documented evidence.
This is an independent learning/portfolio lab. May screenshots, account topology,
cost figures and failover results do not establish today's deployed estate.

## Find the owning contract

Read `README.md` for scope and lifecycle, `docs/ci-safety.md` for execution
boundaries, and the affected `infra/<phase>/README.md` with its providers and
variables. `infra/_backend/README.md` owns state adoption: migration is not
evidenced as complete. Use `docs/03-cost-analysis.md` for the dated cost ledger,
`docs/04-failover-drill.md` for the recorded exercise, and architecture/migration
docs for the design narrative. Do not import another project's operating rules.

## Account, state and effect boundaries

- Preserve credential-free PR/main checks in `.github/workflows/plan.yml`.
  Apply remains manual, with fixed phase choices, exact phase confirmation and the `production`
  environment. Verify actual environment protections before claiming an approval
  gate. `.github/workflows/nightly-teardown.yml` has no schedule; retain destructive
  confirmation and serialized phase execution until state migration is verified.
- Before authorized cloud work, confirm management versus member-account roles,
  provider aliases, primary versus DR region, and the phase's real backend/state.
  The account map is read through SSM by affected phases; a recorded ID is not
  authority to operate that account. Each phase needs its own state ownership
  and key, including the accounts/resources reached by its provider aliases.
- Inventory local and remote state before adoption, stop concurrent applies,
  retain encrypted backups and migrate one phase at a time. Require remote
  object/version, locking and no-op-plan evidence. An empty CI state is neither
  permission to recreate existing resources nor proof of successful teardown.
  Preserve audit logs, keys, data replicas and backend recovery material.
- Organization/account creation, failover, scaling, apply and destroy are live
  operations. `make down` is destructive, not documentation cleanup. Verify a
  Make target in that directory before using it: only the workload phase has
  the daily-operation Makefile. Broad README examples do not create targets in
  other phases. Preflight and cost-snapshot scripts make live AWS reads.
- For an authorized lab session, establish current cost, budget, owned resources
  and cleanup/recovery first. Old credit budgets and prices are historical;
  scaling ECS to zero leaves other billed resources. Preserve the distinction
  between tag-based compute auto-stop and full resource teardown.

## Verify changes

`bash scripts/validate-terraform.sh` is the existing static entry point. It runs
formatting plus backendless init/validate for every phase, including backend
and DNS stacks. It may download providers but does not read state or call AWS.
Use `.github/workflows/plan.yml` for its tool version. Do not replace it with a
live plan to make a documentation or dependency PR pass.

For prose-only changes, review affected links, source declarations and dates.
Changes to IAM, DR or state need checks appropriate to their contract; static
validation cannot establish effective permissions or recovery. Preserve evidence
limits and report unrun acceptance checks. A guide edit must not rerun a drill,
rebuild diagrams unnecessarily or resurrect the lab.

## Writing and delivery

Lead docs and PRs with the concrete change or decision and its consequence.
Explain cross-account handoffs plainly; link receipts instead of repeating logs.
Keep design, historical observation, current inspection and proposed work distinct.
Follow existing commit conventions, otherwise `type: concrete change` (preferably
under 72 characters). Report actual checks, local edits, push/PR effects and live
operations separately; merging static-check changes does not adopt remote state.

.PHONY: help preflight phase-0-plan phase-0-apply cost-snapshot

help:
	@echo "Targets:"
	@echo "  preflight        - check AWS CLI, region, identity, no existing Org"
	@echo "  phase-0-plan     - terraform plan for Org + accounts + SCPs"
	@echo "  phase-0-apply    - terraform apply for Phase 0 (one-time, review carefully)"
	@echo "  cost-snapshot    - dump month-to-date AWS cost by tag"
	@echo ""
	@echo "Phases 1-6 are not wired yet; see plan."

preflight:
	@./scripts/preflight.sh

phase-0-plan:
	cd infra/00-org-bootstrap && terraform init -upgrade && terraform plan -out=phase0.tfplan

phase-0-apply:
	@echo "Phase 0 creates 4 AWS accounts and an Organization."
	@echo "Account close has a 90-day cooldown. Read infra/00-org-bootstrap/README.md first."
	@read -p "Type 'apply' to continue: " ans && [ "$$ans" = "apply" ]
	cd infra/00-org-bootstrap && terraform apply phase0.tfplan

cost-snapshot:
	@./scripts/cost-snapshot.sh

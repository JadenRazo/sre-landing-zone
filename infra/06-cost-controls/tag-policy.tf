# Tag Policy retry — bypassing Terraform's aws_organizations_policy by going
# direct to the AWS CLI in a null_resource. Reason: Phase 0's attempt via the
# Terraform provider returned MalformedPolicyDocumentException for reasons that
# didn't match the published schema. Direct CLI calls show the actual error
# response and let us iterate without re-planning.
#
# This is documented as a deliberate trade-off — Terraform-managed state for
# this resource is given up in exchange for actually getting it deployed.
#
# To detach/destroy: `aws organizations delete-policy --policy-id <id>` after
# detaching from any OUs. Save the ID returned by the create call to enable that.

resource "null_resource" "tag_standards_policy" {
  triggers = {
    # Re-run when this file changes.
    content_hash = filemd5("${path.module}/tag-policy-content.json")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      cd ${path.module}
      # Create policy if it doesn't exist; idempotent.
      EXISTING=$(aws organizations list-policies --filter TAG_POLICY \
        --query "Policies[?Name=='tag-standards'].Id" --output text)
      if [ -z "$EXISTING" ]; then
        echo "Creating tag-standards policy..."
        aws organizations create-policy \
          --name tag-standards \
          --type TAG_POLICY \
          --description "Standard tag keys: Environment, Owner, CostCenter, Project" \
          --content file://tag-policy-content.json
      else
        echo "Policy tag-standards already exists at $EXISTING; skipping create."
      fi
    EOT
  }
}

#!/usr/bin/env bash
set -euo pipefail

export TF_IN_AUTOMATION=1
export TF_PLUGIN_CACHE_DIR="${RUNNER_TEMP:-/tmp}/sre-landing-zone-plugin-cache"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

terraform fmt -check -recursive infra

while IFS= read -r versions_file; do
  phase_dir=$(dirname "$versions_file")
  echo "Validating ${phase_dir}"
  terraform -chdir="$phase_dir" init -backend=false -input=false -no-color
  terraform -chdir="$phase_dir" validate -no-color
done < <(find infra -mindepth 2 -maxdepth 2 -name versions.tf -print | sort)

#!/usr/bin/env bash
# cost-snapshot.sh — dump month-to-date AWS cost grouped by tag, append to ledger.
set -euo pipefail

OUT_DIR="docs/cost-snapshots"
mkdir -p "$OUT_DIR"

START=$(date -u +%Y-%m-01)
END=$(date -u +%Y-%m-%d)
STAMP=$(date -u +%Y-%m-%dT%H-%M-%SZ)
OUT="$OUT_DIR/$STAMP.json"

echo "Fetching cost from $START to $END (UTC)..."

aws ce get-cost-and-usage \
  --time-period "Start=$START,End=$END" \
  --granularity MONTHLY \
  --metrics "UnblendedCost" "UsageQuantity" \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json > "$OUT"

echo "Wrote $OUT"

TOTAL=$(jq -r '.ResultsByTime[0].Total.UnblendedCost.Amount' "$OUT")
echo "Month-to-date total: \$$TOTAL"

# Append summary to the ledger.
LEDGER="docs/03-cost-analysis.md"
{
  echo ""
  echo "### Snapshot $STAMP"
  echo "- Period: $START → $END"
  echo "- Total (Unblended): \$$TOTAL"
  echo ""
  echo "Top 5 services:"
  jq -r '.ResultsByTime[0].Groups | sort_by(.Metrics.UnblendedCost.Amount | tonumber) | reverse | .[0:5][] | "- \(.Keys[0]): $\(.Metrics.UnblendedCost.Amount)"' "$OUT"
} >> "$LEDGER"

echo "Appended summary to $LEDGER"

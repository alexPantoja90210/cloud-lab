#!/usr/bin/env bash
# Destroy layer 1 of one cloud and save a redacted copy of the output.
# Usage: scripts/teardown.sh azure|aws
set -euo pipefail

cloud="${1:-}"
case "$cloud" in
  azure|aws) ;;
  *) echo "usage: $0 azure|aws" >&2; exit 2 ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"
dir="$root/$cloud/layer1"
backend="$dir/backend.local.hcl"
out="$root/evidence/destroy-$cloud-$(date -u +%Y%m%dT%H%M%SZ).txt"

[ -f "$backend" ] || { echo "missing $backend (see $cloud/bootstrap/README.md)" >&2; exit 1; }

terraform -chdir="$dir" init -input=false -no-color -backend-config=backend.local.hcl
# -auto-approve is acceptable here because layer 1 is a separate root from layer 0.
terraform -chdir="$dir" destroy -input=false -no-color -auto-approve 2>&1 \
  | sed -E \
      -e 's/id=Y2xpZW50[A-Za-z0-9+\/=]+/id=<redacted-client-config>/g' \
      -e 's/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F-]*/<redacted-guid>/g' \
      -e 's/\b[0-9]{12}\b/<redacted-account-id>/g' \
  | tee "$out"

echo
echo "Saved: $out"
echo "Read it once before committing. Then do steps 2-4 of docs/closing-ritual.md."

#!/usr/bin/env bash
# Save a redacted copy of what a command printed, as evidence.
#
#   scripts/capture.sh <label> '<command>'        run the command here, stdout and stderr merged
#   <command> 2>&1 | scripts/capture.sh <label>   read the output from a pipe instead
#
# Keep secrets in environment variables and refer to them in the command, for example
#   'curl -s -i $PROBE_URL'
# so they never sit in a file. The command itself is not written to the evidence file; its exit
# code is. Writes evidence/<label>-<UTC timestamp>.txt as UTF-8 with LF line endings.
#
# Fails closed: if anything that looks like a credential, an endpoint or an identifier survives
# redaction, nothing is written. A clean scan is not a guarantee: read the file before committing.
set -euo pipefail

usage() {
  echo "usage: $0 <label> ['<command>']   (label: lowercase letters, digits and dashes)" >&2
  exit 2
}

label="${1:-}"
[[ "$label" =~ ^[a-z0-9][a-z0-9-]*$ ]] || usage
cmd="${2:-}"

root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/evidence"
out="$root/evidence/$label-$(date -u +%Y%m%dT%H%M%SZ).txt"
raw="$(mktemp)"
clean="$(mktemp)"
trap 'rm -f "$raw" "$clean"' EXIT

if [ -n "$cmd" ]; then
  # set -f: no filename expansion, so a ? or * inside a URL taken from a variable stays literal.
  set +e
  bash -c "set -f; $cmd" > "$raw" 2>&1
  code=$?
  set -e
  echo "(exit code: $code)" >> "$raw"
else
  cat > "$raw"
fi

# NUL bytes mean UTF-16 (the PowerShell default). A scan of UTF-16 text reports "clean" for the
# wrong reason, so refuse it.
if [ "$(tr -d '\000' < "$raw" | wc -c)" -ne "$(wc -c < "$raw")" ]; then
  echo "refused: the input has NUL bytes (UTF-16?). Nothing written." >&2
  exit 1
fi

# Normalise line endings and drop a BOM, then redact.
sed -E -e 's/\r$//' -e '1s/^\xEF\xBB\xBF//' "$raw" | sed -E -f "$root/scripts/redact.sed" > "$clean"

if command -v iconv > /dev/null 2>&1 && ! iconv -f UTF-8 -t UTF-8 "$clean" > /dev/null 2>&1; then
  echo "refused: the output is not valid UTF-8. Nothing written." >&2
  exit 1
fi

# Leftover scan. Each entry is "name|pattern". Only line numbers are printed, never the content.
checks=(
  'cloudfront-domain|cloudfront\.net'
  'azure-storage-endpoint|\.core\.windows\.net'
  's3-endpoint|\.amazonaws\.com'
  'signed-url-part|X-Amz-(Signature|Credential|Security-Token)|[?&]sig='
  'aws-access-key-id|\b(AKIA|ASIA)[0-9A-Z]{16}\b'
  'account-id|\b[0-9]{12}\b'
  'aws-arn|arn:aws:'
  'cloudfront-id|\bE[0-9A-Z]{12,13}\b'
  'session-resource-name|cloud-lab-(storage|identity-probe)-[a-z0-9]{8}|stlab(probe|store)[a-z0-9]{6}'
  'guid|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  'long-hex|\b[0-9a-f]{40,}\b'
  'long-token|[A-Za-z0-9+/]{40,}'
)
failed=0
for entry in "${checks[@]}"; do
  name="${entry%%|*}"
  pattern="${entry#*|}"
  if lines="$(grep -n -E "$pattern" "$clean" | cut -d: -f1 | paste -sd, -)" && [ -n "$lines" ]; then
    echo "refused: $name survives redaction at line(s) $lines" >&2
    failed=1
  fi
done
if [ "$failed" -ne 0 ]; then
  echo "Nothing written. Add a rule to scripts/redact.sed or capture less." >&2
  exit 1
fi

cp "$clean" "$out"
cat "$out"
echo
echo "Saved: $out"
echo "Read it once before committing."

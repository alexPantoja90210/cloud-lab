#!/usr/bin/env bash
# k3s lab preflight. Run on node1 before a failure drill. Read-only: changes nothing.
# Usage: bash k3s-preflight.sh [expected_nodes]
# Exit code: 0 = READY, 1 = NOT READY.

set -u
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
EXPECTED_NODES="${1:-2}"
MIN_AVAIL_MB=800
MIN_DISK_GB=3
MIN_UPTIME_S=180
fail=0
warn=0

ok()   { printf 'PASS  %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fail=$((fail + 1)); }
note() { printf 'WARN  %s\n' "$1"; warn=$((warn + 1)); }

# 1. API server answers, and how fast.
t0=$(date +%s%N)
if timeout 15 kubectl get --raw /readyz >/dev/null 2>&1; then
  ms=$(( ($(date +%s%N) - t0) / 1000000 ))
  if [ "$ms" -lt 2000 ]; then ok "API server ready (${ms} ms)"; else note "API server slow (${ms} ms)"; fi
else
  bad "API server not answering within 15 s"
fi

# 2. Every node is Ready, and the count is the expected one.
nodes=$(timeout 15 kubectl get nodes --no-headers 2>/dev/null)
total=$(printf '%s\n' "$nodes" | grep -c .)
ready=$(printf '%s\n' "$nodes" | awk '$2=="Ready"' | grep -c .)
if [ "$total" -eq "$EXPECTED_NODES" ] && [ "$ready" -eq "$total" ]; then
  ok "Nodes ready: $ready of $total"
else
  bad "Nodes ready: $ready of $total (expected $EXPECTED_NODES, all Ready)"
fi

# 3. No taints left from an earlier drill.
tainted=$(timeout 15 kubectl get nodes -o jsonpath='{range .items[*]}{.spec.taints[*].key}{"\n"}{end}' 2>/dev/null | grep -c .)
if [ "$tainted" -eq 0 ]; then ok "No node taints"; else bad "$tainted node(s) carry taints"; fi

# 4. No network mounts. A hard NFS mount blocks this node when its server goes down.
mounted=$(findmnt -rn -t nfs,nfs4,cifs 2>/dev/null | grep -c .)
fstab=$(grep -Ev '^[[:space:]]*#' /etc/fstab 2>/dev/null | grep -Ec '[[:space:]](nfs|nfs4|cifs)[[:space:]]')
if [ "$mounted" -eq 0 ] && [ "$fstab" -eq 0 ]; then
  ok "No network mounts (mounted: 0, active fstab lines: 0)"
else
  bad "Network mounts present (mounted: $mounted, active fstab lines: $fstab)"
fi

# 5. Load is below the CPU count, over 1 and 5 minutes.
cpus=$(nproc)
read -r l1 l5 _ < /proc/loadavg
if awk -v a="$l1" -v b="$l5" -v c="$cpus" 'BEGIN { exit !(a < c && b < c) }'; then
  ok "Load $l1 / $l5 (1 and 5 min) on $cpus CPUs"
else
  bad "Load $l1 / $l5 (1 and 5 min) is not below $cpus CPUs; wait until it settles"
fi

# 6. Memory and disk.
avail=$(free -m | awk 'NR==2 {print $7}')
if [ "$avail" -ge "$MIN_AVAIL_MB" ]; then ok "Memory available: ${avail} MB"; else bad "Memory available: ${avail} MB (minimum $MIN_AVAIL_MB)"; fi
disk=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
if [ "${disk:-0}" -ge "$MIN_DISK_GB" ]; then ok "Disk free on /: ${disk} GB"; else bad "Disk free on /: ${disk} GB (minimum $MIN_DISK_GB)"; fi

# 7. No package manager running (it loads the disk and the CPU after boot).
if pgrep -x 'dnf|dnf5|yum|rpm' >/dev/null 2>&1; then bad "A package manager is running; wait until it finishes"; else ok "No package manager running"; fi

# 8. No processes stuck waiting for disk or network (state D).
dstate=$(ps -eo stat= | grep -c '^D')
if [ "$dstate" -le 1 ]; then ok "Processes blocked on I/O: $dstate"; else bad "Processes blocked on I/O: $dstate"; fi

# 9. The node has been up long enough to settle after boot.
up=$(cut -d. -f1 /proc/uptime)
if [ "$up" -ge "$MIN_UPTIME_S" ]; then ok "Uptime ${up} s"; else bad "Uptime ${up} s (wait for at least $MIN_UPTIME_S s after boot)"; fi

# 10. No kernel trouble in the last 30 minutes (needs permission to read the journal).
klog=$(journalctl -k --since "-30 min" --no-pager -q 2>/dev/null)
if [ -z "$klog" ]; then
  note "Kernel log not readable or empty; not checked"
else
  n=$(printf '%s\n' "$klog" | grep -ciE 'soft lockup|not responding|hung task')
  if [ "$n" -eq 0 ]; then ok "No lockups or hung mounts in the kernel log (30 min)"; else bad "$n kernel message(s) about lockups or unresponsive servers in the last 30 min"; fi
fi

# 11. Pods healthy, and no leftovers from an earlier drill.
badpods=$(timeout 15 kubectl get pods -A --no-headers 2>/dev/null | awk '$4!="Running" && $4!="Completed"' | grep -c .)
if [ "$badpods" -eq 0 ]; then ok "All pods Running or Completed"; else bad "$badpods pod(s) not Running or Completed"; fi
left=$(timeout 15 kubectl get deployments -n default --no-headers 2>/dev/null | grep -c .)
if [ "$left" -eq 0 ]; then ok "No leftover deployments in the default namespace"; else note "$left deployment(s) left in the default namespace"; fi

echo
if [ "$fail" -eq 0 ]; then
  echo "NODE VERDICT: READY ($warn warnings)"
  exit 0
else
  echo "NODE VERDICT: NOT READY ($fail failed, $warn warnings)"
  exit 1
fi

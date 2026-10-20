# Local k3s lab on the two VirtualBox VMs (CLOUD-44, phase 1)

Started 20 Oct 2026. Cost: 0 (all local). Operator runs the commands; output is filtered.

## Set-up

- VMs: node1 (3072 MB, 2 CPU; was 2048) and node2 (2048 MB, 2 CPU), RHEL 10.2, SELinux Enforcing, firewalld active, same NAT network (10.10.10.0/24).
- Host: 15.7 GB RAM; Chrome was using about 6.9 GB and had to be closed first (available memory went from 2.3 GB to 8.2 GB). Rule used: with 5 to 7 GB available start one VM, with 7 GB or more start both.
- Safety: snapshot `before-k3s` taken on both VMs before installing anything.
- k3s minimums read from its documentation: server 2 CPU and 2 GB, agent 1 CPU and 512 MB. RHEL 10 is not named in the page; RHEL needs extra set-up (firewalld rules or disabling it).
- Firewall (both nodes): 8472/udp and 10250/tcp; node1 also 6443/tcp; pod and service ranges 10.42.0.0/16 and 10.43.0.0/16 added to the trusted zone.
- Server installed with the official script (`curl | sh`, runs as root) on node1 at about 15:13; v1.36.5+k3s1; the SELinux policy package came with it and caused no problem.
- Agent joined node2 at about 15:26. About 14 minutes from installer to two Ready nodes, including the troubleshooting below.

## What went wrong, and what it taught

- `sudo k3s` was not found: sudo on RHEL does not search /usr/local/bin. Use the full path.
- `kubectl` read /etc/rancher/k3s/k3s.yaml (root only) and ignored ~/.kube/config until KUBECONFIG was exported.
- The join token could not be pasted into the terminal window. Fix without copy and paste: node1 left a temporary readable copy, node2 fetched it over SSH into a shell variable, then the copy was deleted.
- The agent first logged "failed to validate connection" although port 6443 was open and the MTU was normal (1500/1450). The same HTTPS check answered 200 a minute later, so it was a slow server still starting its pods, not the network. Not proven, but nothing else changed.
- My command used `tail -3` and hid the HTTP check line; the check had to be repeated.

## Drill results (predictions written before running)

| Step | Prediction | Observed |
|---|---|---|
| 2 replicas of nginx | not asked | one pod per node |
| Scale to 4 | not asked | 3 on node1, 1 on node2 (no even spread by default) |
| Drain node2 | pods move, service stays up | 5 s (15:31:35 to 15:31:40); its pod was evicted and a replacement started on node1; service HTTP 200. Weak test: 3 of 4 pods were already on node1, one request only |
| Uncordon node2 | pods move back (wrong) | all 4 pods stayed on node1; Kubernetes does not rebalance |
| Image tag that does not exist | service stays up (right) | HTTP 200 throughout; rolling update kept 3 healthy old pods; the new pods were still ContainerCreating when sampled, ImagePullBackOff not captured |
| Roll back | not asked | `rollout undo`; healthy again 15:37:14 (2 min 15 s after the bad update, including a 45 s wait I set) |

Kubernetes warned that mixing `kubectl scale`, `set image` and `undo` with `kubectl apply` can leave the stored configuration out of step. That is the reason for the GitOps step.

## Not done yet in phase 1

Terraform with the kubernetes provider against this cluster; GitOps (Flux or Argo CD) from this repo; capture of ImagePullBackOff and a failing readiness probe; a stopped node.

## What local practice does not teach

Managed control planes, IAM and workload identity, cloud load balancers, node autoscaling, and the bill.

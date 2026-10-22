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

## Failure drills, 21 Oct 2026 (evening)

| Drill | What was done | Observed |
|---|---|---|
| ImagePullBackOff | Deployment with image `nginx:no-such-tag-xyz` | Events: Scheduled, Pulling, Failed (ErrImagePull), BackOff (ImagePullBackOff), Pulling again. Status alternated between ErrImagePull and ImagePullBackOff. Restarts stayed 0 because the container never started. |
| Failing readiness probe | 2 replicas, probe on a path that does not exist, plus a Service | Pods `Running` but `0/1`, restarts 0, Service endpoints empty. After patching the probe path: `1/1` and two endpoints, one per node. The operator predicted Ready; the pods were Running but not Ready. |
| Stopped node, run 1 | `node2` powered off hard, 4 replicas over both nodes | Invalid. `node1` had `/mnt/shared` mounted from `node2` over NFS with the `hard` option. When `node2` went down, `node1` blocked on that mount: load average above 20 with a mostly idle CPU, soft lockups on both CPUs, kubectl timeouts, and no pod was moved in 14.5 minutes. An early guess that a background `dnf` was the cause was wrong. |
| Stopped node, run 2 | Same, after unmounting the NFS share and commenting its line in `/etc/fstab` (backup `/etc/fstab.bak-cloud44`) | `node2` NotReady about 105 s after the observer started (the power-off was within seconds of that start, so the figure is approximate). `node1` flapped between NotReady and Ready (NotReady at 162 s and 434 s, Ready at 296 s and 523 s); cause not identified. The two pods on `node2` became Terminating at about 523 s. The same line did not list any pod on `node1`, so whether replacement pods were created was not seen: the deployment was deleted before the next observation. |

Pod toleration for node-not-ready and node-unreachable is 300 s (read from the pod spec). The taints `unreachable:NoSchedule` and `unreachable:NoExecute` were present on `node2`.

Lessons:
- Running is not Ready; a failing readiness probe does not restart a container.
- ImagePullBackOff means waiting before the next pull attempt.
- A node that is a dependency of another (here an NFS server) turns a worker failure into a cascade. A `hard` NFS mount blocks everything that touches it.
- An observer must watch the field that actually changes (deletion timestamp, not phase), and its own commands need time limits.
- A two-node cluster whose server node is unstable cannot answer "how fast does Kubernetes evacuate a dead node". When every node is NotReady the controller may pause evictions (a hypothesis, not verified here).

Not explained: why `node1` flapped to NotReady; host memory pressure (VirtualBox windows were open) is a possible contributor, not confirmed.

To repeat cleanly: keep the NFS line disabled, close the VirtualBox windows and other heavy applications, wait for `node1` to be quiet (load average low and stable) before powering off `node2`, and record the exact power-off time from `VBoxManage showvminfo` instead of estimating it.

Still open in phase 1: Terraform versus k3s, GitOps, the operator's own study note.

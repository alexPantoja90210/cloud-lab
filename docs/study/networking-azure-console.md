# Networking on Azure, built by hand (CLOUD-27, 15 Oct 2026)

Built in the portal by the operator from written steps, then read from inside the network with Run
Command on a VM that has no public IP. The resource group `rg-cloud-lab-net-console` was deleted whole at
the end; the subscription check afterwards showed only layer 0 and the two network watchers Azure creates
by itself.

## What was built

One virtual network (`10.70.0.0/16`) with `snet-web` and `snet-db`; a security group on each; a storage
account (LRS, public network access on, anonymous blob access off); a private endpoint for its blob
service in `snet-db` with a private DNS zone; one `Standard_B1s` Ubuntu VM in `snet-web`.
Rules on the db group: 100 allow SQL from web, 150 allow 443 from web to the endpoint (added later),
200 deny Internet, 300 deny everything else from the web subnet.

## What the screens showed about price

Virtual network, subnets and security groups showed no price at all and are free. The storage account
review showed none either. The private endpoint showed none and bills 0.01 USD an hour. Only the VM
wizard showed a price: 0.0120 USD an hour, for compute only, not the Premium OS disk the portal chose by
default. The VM wizard also defaults to creating a public IP, which bills by the hour.

## What the readings showed

- Default rules 65000 `AllowVnetInBound`, 65001 `AllowAzureLoadBalancerInBound` and 65500
  `DenyAllInBound` sit below every custom rule. 65000 lets one subnet reach another in the same network,
  so a "db" subnet is not isolated until a deny is added (rule 300).
- The first address of a subnet the endpoint could take was `.4`: Azure keeps `.0` to `.3` and the last.
- From inside the network the storage name resolved to the private address, because the DNS zone was
  linked to the network. From outside it still resolves to the public address.
- With *private endpoint network policies* **Disabled** (portal default) port 443 from `snet-web` to the
  endpoint was `open` although rule 300 denies that subnet. Setting the policy to *Network security
  groups* made it `blocked`, decided by rule 300. Adding rule 150 made it `open` again.
- A request without credentials from the laptop: `409 Public access is not permitted on this storage
  account` while the network was open (the account refused an anonymous request), `403 This request is
  not authorized to perform this operation` after public network access was turned off (the account's
  firewall refused it).

## Log of surprises (the operator, 15 Oct 2026)

1. Associating everything inside the resource group.
2. After creating the different resources it was hard to find them again quickly.
3. As a project manager: wants fast access to what exists and what it costs. It was a quick exercise, but
   wants the as-is view, to know what is out there and have no surprises.

Follow-up from item 3: `scripts/inventory.ps1` (read-only; types, counts and tags, flags what bills by the
hour).

## Still to read

Cost of the session in Cost analysis (filter `domain = networking`), next day, with its date; then compare
with the CLI report. Open: whether the private endpoint meter shows the hours the portal never displayed.

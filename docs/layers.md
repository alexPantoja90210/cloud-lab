# Layer 0 and layer 1

## Layer 0: survives every teardown

Terraform state backends, budgets and alerts, the tag scheme, identity role definitions, this repository and its evidence, the empty Azure resource group.
Almost all of it is free. The budgets are the control that makes the month safe: destroying a budget alert removes the control.

## Layer 1: destroyed at the end of every session

VMs and their disks, public IPs, load balancers, Bastion, gateways, anything ingesting into Log Analytics, and anything else with an hourly meter.

## Why two roots instead of one with a flag

A flag can be forgotten. Two roots with separate state mean `destroy` in `layer1/` has no path to layer 0.

## Tag scheme (both clouds)

| Tag     | Value                          |
|---------|--------------------------------|
| `lab`   | `cloud-lab`                    |
| `layer` | `0` or `1`                     |

On AWS these are provider `default_tags`. On Azure they are set on the resource group and passed to each resource.

## Azure VM states, for the cost reading

Stopped (Allocated) is billed. Stopped (Deallocated) stops compute billing, but disks and networking still bill. Destroy is the only free state.

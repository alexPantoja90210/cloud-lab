# The PyME model on Azure (CLOUD-36)

How a mid-size company's on-prem access and cost model maps to Azure. The AWS half and the comparison are done in CLOUD-31.

| On-prem | Azure | Evidence from this lab |
|---|---|---|
| A Windows folder per department | A storage account per department with one container | 4 accounts, 4 containers, tag `department` |
| Folder permission for the department | Storage Blob Data Reader granted to an Entra group at container scope | A denial was captured: a member of operations could not list finance |
| New hire, transfer, leaver | Add, move or remove a member of the group; no per-user permission is edited | Join took 17 s for a new identity; a move and a removal were NOT reflected for 8 to 16 minutes (service principals) |
| Domain admin | Owner role | Owner could create a container but not read it: management access is not data access |
| Cost per department and per server | Tag `department` on each resource, read in Cost analysis | Read pending (22 Oct) |

## What to take away

- Access is given to groups, never to people. Moving someone is a membership change.
- Two layers: managing a resource and reading its data are different permissions.
- Removing someone from a group is not an instant revoke; measure the delay before promising one.
- One resource per department is what makes the cost split possible; a container cannot be tagged.

Not covered: human users (MFA at first sign-in), deny assignments, conditions on role assignments, budgets per tag.

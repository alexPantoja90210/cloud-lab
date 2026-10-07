# AWS layer 0 bootstrap

Creates, once: a private, versioned, encrypted, TLS-only S3 bucket for layer 1 state. Locking uses S3 native lock files (`use_lockfile`), so there is no DynamoDB table.

State for this folder is **local** (the bucket cannot store its own creation). The local `terraform.tfstate` is gitignored; keep a copy outside the repository.

```
export AWS_PROFILE="<your profile>"     # in your shell, never in a file
terraform -chdir=aws/bootstrap init
terraform -chdir=aws/bootstrap apply
terraform -chdir=aws/bootstrap output -raw backend_config > aws/layer1/backend.local.hcl
git check-ignore -v aws/layer1/backend.local.hcl aws/bootstrap/terraform.tfstate
```

Cost: kilobytes of state, well under a cent per month. The bucket has `prevent_destroy`; running `destroy` here fails on purpose.

# Sensitive on purpose: the ARN contains the account ID, which must not reach logs or evidence.
# Read it with:  terraform -chdir=aws/identity output -raw role_arn
output "role_arn" {
  value     = aws_iam_role.s3_reader.arn
  sensitive = true
}

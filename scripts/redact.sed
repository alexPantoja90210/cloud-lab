# Shared redaction rules for anything that may reach the public repository.
# Used by scripts/teardown.sh and scripts/capture.sh. A filter, not a guarantee:
# read every file in evidence/ before committing.

# Identifiers seen in Terraform output (CLOUD-23 to CLOUD-24).
s/id=Y2xpZW50[A-Za-z0-9+\/=]+/id=<redacted-client-config>/g
s/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F-]*/<redacted-guid>/g
s/\b[0-9]{12}\b/<redacted-account-id>/g
s/\b[0-9a-f]{64}\b/<redacted-canonical-id>/g

# CLOUD-26: endpoints, request ids and signed-URL parts.
s/[A-Za-z0-9-]+\.cloudfront\.net/<redacted-cloudfront-domain>/g
s/[A-Za-z0-9.-]+\.s3[A-Za-z0-9.-]*\.amazonaws\.com/<redacted-s3-endpoint>/g
s/[A-Za-z0-9-]+\.(blob|dfs|file|queue|table|web)\.core\.windows\.net/<redacted-azure-storage-endpoint>/g
s/(https?:\/\/[^ "'?]*)\?[^ "']*/\1?<redacted-query>/g
s/(X-Amz-[A-Za-z-]+|sig|skoid|sktid)=[^& "']+/\1=<redacted>/g
s/((x-amz-id-2|x-amz-request-id|x-amz-cf-id|x-ms-request-id|x-ms-client-request-id):) *.*/\1 <redacted>/I
s/<(HostId|RequestId)>[^<]*<\/\1>/<\1><redacted><\/\1>/g

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

# CLOUD-26: resource identifiers that Terraform prints (ARNs, CloudFront ids, session names).
# ARNs go first so everything inside them is covered, including the S3 form without an account.
s/arn:aws:[^]" ,]+/<redacted-arn>/g
s/\bE[0-9A-Z]{12,13}\b/<redacted-cloudfront-id>/g
s/cloud-lab-(storage|identity-probe|rehost)-[a-z0-9]{8}/cloud-lab-\1-<redacted-suffix>/g
s/stlab(probe|store)[a-z0-9]{6}/stlab\1<redacted-suffix>/g
s/^( *[-+~]? *etag +=) "[^"]*"/\1 "<redacted-etag>"/

# CLOUD-28: API Gateway HTTP API. The API id is a 10-character lowercase id that appears in the
# invoke URL, in id= and api_id= attributes, and inside route and integration ids.
s/[a-z0-9]{10}\.execute-api\.[a-z0-9-]+\.amazonaws\.com/<redacted-api-endpoint>/g
s/\b(id|api_id|integration_id) +(=|:) +"[a-z0-9]{10}"/\1 \2 "<redacted-api-id>"/g
s/\[id=[a-z0-9]{7,10}\]/[id=<redacted-api-id>]/g
s/(ssh-rsa|-----BEGIN [A-Z ]+-----)[A-Za-z0-9+\/=\\n -]*/\1 <redacted-key>/g

# CLOUD-28 (second pass, from reading the first compute destroy output): short ids of API Gateway
# children, IAM role unique id, NIC MAC address, key fingerprints, PEM body lines, disk name suffix,
# and the sha1 ids that Terraform prints for generated keys and archives.
s/^( *- *id) +(=) +"[a-z]*[0-9][a-z0-9]*"/\1 \2 "<redacted-id>"/
s/(deployment_id +=) "[a-z0-9]+"/\1 "<redacted-id>"/
s/(integrations\/)[a-z0-9]{5,10}/\1<redacted-id>/g
s/(unique_id +=) "[A-Z0-9]{21}"/\1 "<redacted-unique-id>"/
s/\[id=[0-9a-f]{40}\]/[id=<redacted-hash>]/
s/(fingerprint_(md5|sha256) +=) "[^"]*"/\1 "<redacted-fingerprint>"/
s/\b([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2}\b/<redacted-mac>/g
s/^ +[A-Za-z0-9+\/]{40,}={0,2}$/            <redacted-key-body>/
s/(disk[0-9]+_)[0-9a-f]{32}/\1<redacted-suffix>/g

# CLOUD-38: random_string results (bucket name suffixes) printed by Terraform.
s/(result +=) "[a-z0-9]{8}"/\1 "<redacted-suffix>"/

# CLOUD-38: EC2 and VPC identifiers printed by Terraform, and the operator's own address in an allow rule.
s/\b(vpc|sg|sgr|subnet|eni|vol|snap|ami|i)-[0-9a-f]{8,17}\b/<redacted-\1-id>/g
s/\b([0-9]{1,3}\.){3}[0-9]{1,3}\/32\b/<redacted-ip>\/32/g

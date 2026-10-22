"""CLOUD-27 network client: lists one S3 bucket from inside the private subnet.

Same behaviour as the console-built client: short timeouts, one attempt, and a small JSON answer.
Without a route to S3, or with a network ACL that denies, the call ends in silence and the function
times out; the answer below is only produced when the network lets the call through.
"""
import os

import boto3
from botocore.config import Config


def handler(event, context):
    bucket = os.environ["BUCKET"]
    client = boto3.client(
        "s3",
        config=Config(connect_timeout=3, read_timeout=3, retries={"max_attempts": 0}),
    )
    try:
        response = client.list_objects_v2(Bucket=bucket, MaxKeys=5)
        return {"result": "ok", "key_count": response.get("KeyCount", 0)}
    except Exception as error:  # noqa: BLE001 - the exercise wants the error class, whatever it is
        return {"result": "failed", "error": type(error).__name__}

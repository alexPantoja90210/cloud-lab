import json


def handler(event, context):
    # Every request gets the same answer. What this function costs is the point, not what it says.
    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps({"message": "hello from cloud-lab"}),
    }

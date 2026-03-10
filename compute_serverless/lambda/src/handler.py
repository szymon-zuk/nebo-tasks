import json
import logging
import os
from datetime import datetime, timezone

import boto3
from botocore.config import Config

CLOUDWATCH_NAMESPACE = os.getenv("CLOUDWATCH_NAMESPACE", "ComputeServerless/EBSMetrics")

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

session = boto3.Session()


def get_region() -> str:
    region = session.region_name
    if region is None:
        raise RuntimeError("AWS region is not set in the session")
    return region


def collect_ebs_metrics(region: str) -> dict:
    ec2 = session.client(
        "ec2",
        region_name=region,
        config=Config(retries={"max_attempts": 3, "mode": "standard"}),
    )

    unattached_count = 0
    unattached_size_gib = 0
    unencrypted_volumes = 0
    unencrypted_snapshots = 0

    vol_paginator = ec2.get_paginator("describe_volumes")
    for page in vol_paginator.paginate():
        for vol in page.get("Volumes", []):
            if vol.get("State") != "in-use":
                unattached_count += 1
                unattached_size_gib += vol.get("Size", 0)
            if not vol.get("Encrypted", False):
                unencrypted_volumes += 1

    snap_paginator = ec2.get_paginator("describe_snapshots")
    for page in snap_paginator.paginate(OwnerIds=["self"]):
        for snap in page.get("Snapshots", []):
            if not snap.get("Encrypted", False):
                unencrypted_snapshots += 1

    return {
        "region": region,
        "UnattachedVolumes": unattached_count,
        "UnattachedVolumesTotalSizeGiB": unattached_size_gib,
        "UnencryptedVolumes": unencrypted_volumes,
        "UnencryptedSnapshots": unencrypted_snapshots,
    }


def publish_metrics(metrics: dict, region: str) -> int:
    cw = session.client("cloudwatch", region_name=region)
    metric_data = [
        {
            "MetricName": "UnattachedVolumes",
            "Unit": "Count",
            "Value": metrics["UnattachedVolumes"],
        },
        {
            "MetricName": "UnattachedVolumesTotalSizeGiB",
            "Unit": "Gigabytes",
            "Value": metrics["UnattachedVolumesTotalSizeGiB"],
        },
        {
            "MetricName": "UnencryptedVolumes",
            "Unit": "Count",
            "Value": metrics["UnencryptedVolumes"],
        },
        {
            "MetricName": "UnencryptedSnapshots",
            "Unit": "Count",
            "Value": metrics["UnencryptedSnapshots"],
        },
    ]

    cw.put_metric_data(Namespace=CLOUDWATCH_NAMESPACE, MetricData=metric_data)
    return len(metric_data)


def lambda_handler(event, context):
    invocation_time = datetime.now(timezone.utc).isoformat()
    request_id = getattr(context, "aws_request_id", "local")

    logger.info(
        json.dumps(
            {
                "event": "invocation_start",
                "request_id": request_id,
                "timestamp": invocation_time,
                "trigger": event.get("source", "manual"),
            }
        )
    )

    try:
        region = get_region()
        metrics = collect_ebs_metrics(region)

        logger.info(
            json.dumps(
                {
                    "event": "metrics_collected",
                    "request_id": request_id,
                    "namespace": CLOUDWATCH_NAMESPACE,
                    "region": region,
                    "metrics": metrics,
                }
            )
        )

        metrics_count = publish_metrics(metrics, region)

        logger.info(
            json.dumps(
                {
                    "event": "metrics_published",
                    "request_id": request_id,
                    "metrics_sent": metrics_count,
                }
            )
        )

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": "EBS metrics collected and published successfully",
                    "region": region,
                    "namespace": CLOUDWATCH_NAMESPACE,
                    "metrics": metrics,
                    "metrics_sent": metrics_count,
                }
            ),
        }

    except Exception as e:
        logger.error(
            json.dumps(
                {
                    "event": "invocation_error",
                    "request_id": request_id,
                    "error_type": type(e).__name__,
                    "error_message": str(e),
                }
            )
        )
        raise

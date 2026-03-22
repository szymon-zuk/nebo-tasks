import logging
import os
import time
import uuid

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

app = FastAPI()
logger = logging.getLogger(__name__)

SERVICE_NAME = "fastapi-custom-metrics"
METRIC_NAMESPACE = "CustomMetricsLogging/App"
AWS_REGION = "eu-central-1"

_cloudwatch_client = boto3.client("cloudwatch", region_name=AWS_REGION)


def _dims_endpoint(path: str) -> list[dict]:
    return [{"Name": "Service", "Value": SERVICE_NAME}, {"Name": "Endpoint", "Value": path}]


_DIMS_SERVICE_ONLY = [{"Name": "Service", "Value": SERVICE_NAME}]


def publish_metrics(metric_data: list[dict]) -> bool:
    try:
        _cloudwatch_client.put_metric_data(
            Namespace=METRIC_NAMESPACE,
            MetricData=metric_data,
        )
        return True
    except (BotoCoreError, ClientError) as exc:
        logger.error("Failed to publish metrics: %s", exc)
        return False


def publish_request_metrics(
    path: str,
    start: float,
    *,
    http_status: int,
    business_metric: str | None = None,
) -> None:
    """RequestLatencyMs always; ErrorCount only when http_status >= 400; business counter on 2xx/3xx only."""
    ms = (time.perf_counter() - start) * 1000.0
    dim = _dims_endpoint(path)
    data: list[dict] = [
        {"MetricName": "RequestLatencyMs", "Dimensions": dim, "Unit": "Milliseconds", "Value": round(ms, 2)}
    ]
    if http_status >= 400:
        data.append({"MetricName": "ErrorCount", "Dimensions": dim, "Unit": "Count", "Value": 1.0})
    if http_status < 400 and business_metric:
        data.append(
            {
                "MetricName": business_metric,
                "Dimensions": _DIMS_SERVICE_ONLY,
                "Unit": "Count",
                "Value": 1.0,
            }
        )
    publish_metrics(data)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def read_root():
    start = time.perf_counter()
    publish_request_metrics("/", start, http_status=200)
    return {"message": "Hello, World!"}


@app.get("/Welcome")
def welcome(name: str):
    start = time.perf_counter()
    publish_request_metrics("/Welcome", start, http_status=200)
    return {"message": f"Welcome {name}!"}


@app.get("/error")
def trigger_error():
    start = time.perf_counter()
    publish_request_metrics("/error", start, http_status=500)
    return JSONResponse(status_code=500, content={"error": "Intentional error for testing"})


@app.get("/slow")
def slow_endpoint():
    start = time.perf_counter()
    time.sleep(0.15)
    publish_request_metrics("/slow", start, http_status=200)
    return {"message": "Slow response"}


@app.post("/orders")
def mock_create_order():
    start = time.perf_counter()
    publish_request_metrics("/orders", start, http_status=200, business_metric="OrdersCount")
    return {"order_id": str(uuid.uuid4()), "status": "created"}


@app.post("/auth/login")
def mock_login():
    start = time.perf_counter()
    uid = str(uuid.uuid4())
    publish_request_metrics("/auth/login", start, http_status=200, business_metric="UserLoginCount")
    return {"token": f"mock-{uid[:8]}", "user_id": uid}


@app.post("/auth/signup")
def mock_signup():
    start = time.perf_counter()
    uid = str(uuid.uuid4())
    publish_request_metrics("/auth/signup", start, http_status=200, business_metric="UserSignupCount")
    return {"user_id": uid, "status": "registered"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)

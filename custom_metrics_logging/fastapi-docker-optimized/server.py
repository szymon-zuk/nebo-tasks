import json
import threading
import time

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware

app = FastAPI()

# Gauge for in-flight requests (used when emitting ActiveRequests).
_active_requests = 0
_active_requests_lock = threading.Lock()


def _flush_metrics(path: str, status_code: int, latency_ms: float, active_after: int) -> None:
    """Write an EMF (Embedded Metric Format) JSON line to stdout.

    CloudWatch Logs automatically extracts metrics from this format.
    No async flush or CloudWatch Agent required -- just structured JSON to stdout.
    """
    timestamp_ms = int(time.time() * 1000)

    metrics_definitions = [
        {"Name": "RequestCount", "Unit": "Count"},
        {"Name": "RequestLatencyMs", "Unit": "Milliseconds"},
        {"Name": "ActiveRequests", "Unit": "Count"},
        {"Name": "EndpointInvocations", "Unit": "Count"},
    ]
    if status_code >= 400:
        metrics_definitions.append({"Name": "ErrorCount", "Unit": "Count"})

    emf_payload = {
        "_aws": {
            "Timestamp": timestamp_ms,
            "CloudWatchMetrics": [
                {
                    "Namespace": "CustomMetricsLogging/App",
                    "Dimensions": [["Service", "Endpoint"]],
                    "Metrics": metrics_definitions,
                }
            ],
        },
        # Dimension values
        "Service": "fastapi-custom-metrics",
        "Endpoint": path,
        # Metric values
        "RequestCount": 1,
        "RequestLatencyMs": round(latency_ms, 2),
        "ActiveRequests": active_after,
        "EndpointInvocations": 1,
    }
    if status_code >= 400:
        emf_payload["ErrorCount"] = 1

    # EMF: one JSON object per line to stdout
    print(json.dumps(emf_payload), flush=True)


class EMFMetricsMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        global _active_requests
        start = time.perf_counter()
        with _active_requests_lock:
            _active_requests += 1
            active_at_start = _active_requests
        status_code = 500
        try:
            response = await call_next(request)
            status_code = response.status_code
            return response
        finally:
            with _active_requests_lock:
                _active_requests -= 1
                active_after = _active_requests
            latency_ms = (time.perf_counter() - start) * 1000.0
            path = request.url.path or "/"
            _flush_metrics(path, status_code, latency_ms, active_after)


app.add_middleware(EMFMetricsMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def read_root():
    return {"message": "Hello, World!"}


@app.get("/Welcome")
def welcome(name: str):
    return {"message": f"Welcome {name}!"}


@app.get("/error")
def trigger_error():
    """Endpoint that returns 500 for testing ErrorCount and alerts."""
    from fastapi.responses import JSONResponse

    return JSONResponse(status_code=500, content={"error": "Intentional error for testing"})


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)

import json
import os
import subprocess
import sys

CLOUDWATCH_NAMESPACE = "Custom/EC2Monitoring"
MOUNT_POINT = "/"


def run_cmd(cmd):
    """Run a shell command and return the output."""
    try:
        result = subprocess.run(
            cmd, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        return result.stdout.decode().strip()
    except subprocess.CalledProcessError as e:
        print(f"Command '{cmd}' failed with error: {e.stderr.decode().strip()}")
        sys.exit(1)


def get_instance_id():
    """Retrieve the EC2 instance ID from the metadata service."""
    cmd = "curl -s http://169.254.169.254/latest/meta-data/instance-id"
    return run_cmd(cmd)


def get_memory_usage():
    """Get memory usage as:

    - used %
    - total in MB
    - used in MB
    """
    meminfo = {}
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                key, value = line.split(":", 1)
                meminfo[key.strip()] = value.strip()
    except FileNotFoundError as e:
        print(f"Error reading /proc/meminfo: {e}", file=sys.stderr)
        return None, None, None

    def get_kb(key):
        return int(meminfo.get(key, "0 kB").split()[0])

    mem_total_kb = get_kb("MemTotal")
    mem_available_kb = get_kb("MemAvailable")

    if mem_total_kb == 0:
        return None, None, None

    mem_used_kb = mem_total_kb - mem_available_kb
    mem_used_percent = (mem_used_kb / mem_total_kb) * 100

    mem_total_mb = mem_total_kb / 1024
    mem_used_mb = mem_used_kb / 1024
    return mem_used_percent, mem_total_mb, mem_used_mb


def get_disk_usage():
    """Get disk usage for the specified mount point as:
    - used %
    - total in GB
    - used in GB
    """
    output = subprocess.check_output("df -h / | tail -1", shell=True).decode()
    parts = output.split()
    used_percent = float(parts[4].strip("%"))
    total_gb = float(parts[1].strip("G"))
    used_gb = float(parts[2].strip("G"))
    return used_percent, total_gb, used_gb


def publish_metrics(namespace, metric_name, value, unit, dimensions):
    """Publish a custom metric to CloudWatch.

    Dimensions: list of key-value pairs, e.g. [{'Name': 'InstanceId', 'Value': 'i-1234567890abcdef0'}]
    """
    dim_parts = []
    for d in dimensions:
        name = d.get("Name")
        val = d.get("Value")
        dim_parts.append(f"Name={name},Value={val}")
    dim_str = " ".join(dim_parts)

    cmd = (
        f"aws cloudwatch put-metric-data "
        f"--namespace '{namespace}' "
        f"--metric-name '{metric_name}' "
        f"--value {value} "
        f"--unit {unit} "
        f"--dimensions {dim_str}"
    )
    out = run_cmd(cmd)
    if out is not None:
        print(f"[INFO] Published metric {metric_name} with value {value} {unit}")


def main():
    """Main entry point for the monitoring script."""
    instance_id = get_instance_id()
    if not instance_id:
        print("Failed to retrieve instance ID.", file=sys.stderr)
        sys.exit(1)
    dimensions = [{"Name": "InstanceId", "Value": instance_id}]

    # Memory Metrics
    mem_used_percent, mem_total_mb, mem_used_mb = get_memory_usage()
    if mem_used_percent is not None:
        publish_metrics(
            CLOUDWATCH_NAMESPACE,
            "MemoryUsedPercent",
            mem_used_percent,
            "Percent",
            dimensions,
        )
        publish_metrics(
            CLOUDWATCH_NAMESPACE, "MemoryTotalMB", mem_total_mb, "Megabytes", dimensions
        )
        publish_metrics(
            CLOUDWATCH_NAMESPACE, "MemoryUsedMB", mem_used_mb, "Megabytes", dimensions
        )

    # Disk Metrics
    disk_used_percent, disk_total_gb, disk_used_gb = get_disk_usage()
    if disk_used_percent is not None:
        publish_metrics(
            CLOUDWATCH_NAMESPACE,
            "DiskUsedPercent",
            disk_used_percent,
            "Percent",
            dimensions,
        )
        publish_metrics(
            CLOUDWATCH_NAMESPACE, "DiskTotalGB", disk_total_gb, "Gigabytes", dimensions
        )
        publish_metrics(
            CLOUDWATCH_NAMESPACE, "DiskUsedGB", disk_used_gb, "Gigabytes", dimensions
        )


if __name__ == "__main__":
    main()

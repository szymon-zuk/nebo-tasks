#!/bin/bash
set -euo pipefail

echo "=== Configuring nginx ==="

cat > /var/www/html/index.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Custom AMI Instance</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 600px; margin: 60px auto; padding: 0 20px; color: #333; }
    h1 { color: #232f3e; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    td, th { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background: #232f3e; color: #fff; }
    .status { color: #1a8917; font-weight: bold; }
  </style>
</head>
<body>
  <h1>Custom AMI Instance</h1>
  <p>Running on a pre-baked Ubuntu 24.04 LTS image built with Packer.</p>
  <table>
    <tr><th>Component</th><th>Status</th></tr>
    <tr><td>nginx</td><td class="status">Active</td></tr>
    <tr><td>stress-ng</td><td class="status">Installed</td></tr>
    <tr><td>CloudWatch Agent</td><td class="status">Installed</td></tr>
    <tr><td>HashiCorp Vault</td><td class="status">Installed</td></tr>
    <tr><td>Poetry</td><td class="status">Installed</td></tr>
    <tr><td>Instance ID</td><td id="iid">loading...</td></tr>
  </table>
  <script>
    (async () => {
      try {
        const token = await fetch("http://169.254.169.254/latest/api/token", {
          method: "PUT", headers: {"X-aws-ec2-metadata-token-ttl-seconds": "21600"}
        }).then(r => r.text());
        const id = await fetch("http://169.254.169.254/latest/meta-data/instance-id", {
          headers: {"X-aws-ec2-metadata-token": token}
        }).then(r => r.text());
        document.getElementById("iid").textContent = id;
      } catch (e) {
        document.getElementById("iid").textContent = "unavailable";
      }
    })();
  </script>
</body>
</html>
HTML

systemctl enable nginx

echo "=== nginx configuration complete ==="

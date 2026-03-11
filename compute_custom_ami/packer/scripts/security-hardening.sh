#!/bin/bash
set -euo pipefail

echo "=== Applying security hardening ==="

# --- SSH hardening ---
SSHD_CONFIG="/etc/ssh/sshd_config"

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' "$SSHD_CONFIG"
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' "$SSHD_CONFIG"
sed -i 's/^#\?ClientAliveInterval.*/ClientAliveInterval 300/' "$SSHD_CONFIG"
sed -i 's/^#\?ClientAliveCountMax.*/ClientAliveCountMax 2/' "$SSHD_CONFIG"

if ! grep -q "^Protocol 2" "$SSHD_CONFIG"; then
  echo "Protocol 2" >> "$SSHD_CONFIG"
fi

# --- Default umask ---
sed -i 's/^UMASK.*/UMASK 027/' /etc/login.defs

# --- Restrict core dumps ---
echo "* hard core 0" >> /etc/security/limits.d/core.conf

# --- Audit logging ---
systemctl enable auditd

cat > /etc/audit/rules.d/hardening.rules <<'RULES'
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-w /var/log/auth.log -p wa -k authlog
-a always,exit -F arch=b64 -S execve -k exec
RULES

# --- Disable unused services ---
for svc in avahi-daemon cups bluetooth; do
  if systemctl list-unit-files "${svc}.service" &>/dev/null; then
    systemctl disable "$svc" 2>/dev/null || true
    systemctl stop "$svc" 2>/dev/null || true
  fi
done

# --- Restrict permissions on sensitive files ---
chmod 600 /etc/ssh/sshd_config
chmod 640 /etc/shadow
chmod 644 /etc/passwd
chmod 644 /etc/group

echo "=== Security hardening complete ==="

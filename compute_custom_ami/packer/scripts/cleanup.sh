#!/bin/bash
set -euo pipefail

echo "=== Cleaning up for AMI snapshot ==="

apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

rm -rf /tmp/* /var/tmp/*

rm -f /var/log/*.gz /var/log/*.[0-9] /var/log/*.old
cat /dev/null > /var/log/wtmp
cat /dev/null > /var/log/lastlog
cat /dev/null > /var/log/auth.log
cat /dev/null > /var/log/syslog

rm -f /root/.bash_history
rm -f /home/ubuntu/.bash_history
unset HISTFILE

# Reduce AMI size by zero-filling free space
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY
sync

echo "=== Cleanup complete ==="

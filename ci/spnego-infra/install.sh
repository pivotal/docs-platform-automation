#!/bin/bash
# Install SPNEGO Infrastructure as a systemd service
#
# Prerequisites:
#   Create /opt/spnego-infra/env with:
#     DOCKER_REGISTRY_PASSWORD=<your-jfrog-api-key>
#
# Run this on the jumpbox worker:
#   sudo ./install.sh
#
# After installation:
#   sudo systemctl status spnego-infra
#   sudo systemctl restart spnego-infra

set -eux

INSTALL_DIR="/opt/spnego-infra"

echo "=== Installing SPNEGO Infrastructure Service ==="

# Create install directory
mkdir -p ${INSTALL_DIR}

# Copy setup script
cp setup-spnego-infra.sh ${INSTALL_DIR}/
chmod +x ${INSTALL_DIR}/setup-spnego-infra.sh

# Install systemd service
cp spnego-infra.service /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable and start service
systemctl enable spnego-infra
systemctl start spnego-infra

# Show status
echo ""
echo "=== Service Status ==="
systemctl status spnego-infra --no-pager

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Commands:"
echo "  systemctl status spnego-infra   # Check status"
echo "  systemctl restart spnego-infra  # Restart"
echo "  journalctl -u spnego-infra      # View logs"
echo ""

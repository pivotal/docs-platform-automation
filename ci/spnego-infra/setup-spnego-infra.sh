#!/bin/bash
# SPNEGO Test Infrastructure Setup
#
# Run this on the jumpbox worker to set up KDC + Squid proxy for SPNEGO testing.
# This script is idempotent - safe to run multiple times.
#
# Usage:
#   sudo ./setup-spnego-infra.sh

set -eux

PROXY_PORT=13128
REALM="TEST.LOCAL"
TEST_USER="testuser"
TEST_PASSWORD="testpass123"

# Use internal registry to avoid Docker Hub rate limits
DOCKER_REGISTRY="${DOCKER_REGISTRY:-tas-operability-docker-virtual.usw1.packages.broadcom.com}"
DOCKER_REGISTRY_USERNAME="${DOCKER_REGISTRY_USERNAME:-svc-tas-operability}"
DOCKER_REGISTRY_PASSWORD="${DOCKER_REGISTRY_PASSWORD:?ERROR: DOCKER_REGISTRY_PASSWORD environment variable must be set}"
KRB5_IMAGE="${DOCKER_REGISTRY}/gcavalcante8808/krb5-server:latest"
SQUID_IMAGE="${DOCKER_REGISTRY}/ubuntu/squid:latest"

echo "=== Setting up SPNEGO Test Infrastructure ==="
echo "Using registry: ${DOCKER_REGISTRY}"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed"
    exit 1
fi

# Login to internal registry
echo "Logging in to Docker registry..."
echo "${DOCKER_REGISTRY_PASSWORD}" | docker login ${DOCKER_REGISTRY} -u "${DOCKER_REGISTRY_USERNAME}" --password-stdin

# Cleanup existing containers
echo "Cleaning up existing containers..."
docker rm -f spnego-kdc spnego-proxy 2>/dev/null || true
docker network rm spnego-net 2>/dev/null || true

# Create network
echo "Creating Docker network..."
docker network create spnego-net

# Start KDC
echo "Starting KDC container..."
docker run -d \
    --name spnego-kdc \
    --hostname kdc.test.local \
    --network spnego-net \
    --restart unless-stopped \
    -e KRB5_REALM=${REALM} \
    -e KRB5_KDC=kdc.test.local \
    ${KRB5_IMAGE}

# Wait for KDC to initialize
echo "Waiting for KDC to initialize..."
sleep 15

# Create test principals
echo "Creating Kerberos principals..."
timeout 30 docker exec spnego-kdc kadmin.local -q "addprinc -pw ${TEST_PASSWORD} ${TEST_USER}@${REALM}" || true
timeout 30 docker exec spnego-kdc kadmin.local -q "addprinc -pw proxypass HTTP/proxy.test.local@${REALM}" || true

# Create Squid config
echo "Creating Squid configuration..."
cat > /tmp/squid.conf << 'EOF'
http_port 3128
acl all src all
http_access allow all
cache deny all
access_log none
cache_log /var/log/squid/cache.log
EOF

# Start Squid proxy
echo "Starting Squid proxy container..."
docker run -d \
    --name spnego-proxy \
    --hostname proxy.test.local \
    --network spnego-net \
    --restart unless-stopped \
    -p 0.0.0.0:${PROXY_PORT}:3128 \
    -v /tmp/squid.conf:/etc/squid/squid.conf:ro \
    ${SQUID_IMAGE}

# Wait for proxy to start
sleep 5

# Verify
echo ""
echo "=== Verifying Infrastructure ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Test proxy
echo ""
echo "Testing proxy connectivity..."
if curl -s --proxy http://localhost:${PROXY_PORT} --max-time 10 -I http://google.com 2>/dev/null | grep -q "HTTP/"; then
    echo "Proxy is working!"
else
    echo "WARNING: Proxy test failed"
fi

# Get IP for clients
HOST_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "=== SPNEGO Infrastructure Ready ==="
echo ""
echo "Proxy URL: http://${HOST_IP}:${PROXY_PORT}"
echo "KDC Realm: ${REALM}"
echo "Test User: ${TEST_USER}@${REALM}"
echo "Password:  ${TEST_PASSWORD}"
echo ""
echo "Use this proxy URL in your download-config.yml"
echo ""
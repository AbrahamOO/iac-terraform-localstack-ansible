#!/bin/bash

set -e

echo "=========================================="
echo "Starting Localstack Setup"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${YELLOW}Error: Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Docker is running"

# Start Localstack
echo ""
echo "Starting Localstack container..."
docker-compose up -d

# Wait for Localstack to be ready
echo ""
echo "Waiting for Localstack to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:4566/_localstack/health | grep -q "\"s3\": \"running\""; then
        echo -e "${GREEN}✓${NC} Localstack is ready"
        break
    fi
    attempt=$((attempt + 1))
    echo "Attempt $attempt/$max_attempts - waiting for Localstack..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${YELLOW}Warning: Localstack health check timed out, but continuing...${NC}"
fi

# Create S3 bucket for Terraform state
echo ""
echo "Creating S3 bucket for Terraform state..."
aws --endpoint-url=http://localhost:4566 s3 mb s3://terraform-state 2>/dev/null || echo "Bucket already exists"
echo -e "${GREEN}✓${NC} S3 bucket 'terraform-state' ready"

# Verify setup
echo ""
echo "=========================================="
echo "Localstack Setup Complete!"
echo "=========================================="
echo "Services available at: http://localhost:4566"
echo ""
echo "Next steps:"
echo "  1. Run './scripts/apply_terraform.sh' to provision infrastructure"
echo "  2. Run './scripts/run_ansible.sh' to configure the instances"
echo "=========================================="

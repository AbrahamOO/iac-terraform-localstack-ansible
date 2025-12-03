#!/bin/bash

set -e

echo "=========================================="
echo "Applying Terraform Configuration"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Navigate to Terraform directory
cd terraform

# Check if Localstack is running
if ! curl -s http://localhost:4566/_localstack/health > /dev/null; then
    echo -e "${YELLOW}Error: Localstack is not running.${NC}"
    echo "Please run './scripts/setup_localstack.sh' first."
    exit 1
fi

echo -e "${GREEN}✓${NC} Localstack is running"
echo ""

# Initialize Terraform
echo -e "${BLUE}Initializing Terraform...${NC}"
terraform init -reconfigure

echo ""
echo -e "${BLUE}Planning infrastructure changes...${NC}"
terraform plan -out=tfplan

echo ""
read -p "Apply these changes? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Terraform apply cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}Applying Terraform configuration...${NC}"
terraform apply tfplan

rm -f tfplan

echo ""
echo "=========================================="
echo "Infrastructure Provisioning Complete!"
echo "=========================================="
echo ""
echo -e "${GREEN}Terraform Outputs:${NC}"
terraform output

echo ""
echo "=========================================="
echo "Next steps:"
echo "  1. Run './scripts/run_ansible.sh' to configure the instances"
echo "  2. Verify with 'curl http://localhost:8080' (if port forwarding is set up)"
echo "=========================================="

cd ..

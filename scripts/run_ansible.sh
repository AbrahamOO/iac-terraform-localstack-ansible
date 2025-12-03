#!/bin/bash

set -e

echo "=========================================="
echo "Running Ansible Configuration"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Navigate to Ansible directory
cd ansible

# Make inventory script executable
chmod +x dynamic_inventory.py

# Check if Terraform state exists
if ! cd ../terraform && terraform state list > /dev/null 2>&1; then
    echo -e "${YELLOW}Error: No Terraform state found.${NC}"
    echo "Please run './scripts/apply_terraform.sh' first."
    exit 1
fi

cd ../ansible

echo -e "${GREEN}✓${NC} Terraform state found"
echo ""

# Test dynamic inventory
echo -e "${BLUE}Testing dynamic inventory...${NC}"
if ./dynamic_inventory.py --list > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Dynamic inventory is working"
else
    echo -e "${YELLOW}Warning: Dynamic inventory test failed, but continuing...${NC}"
fi

echo ""
echo -e "${BLUE}Running Ansible playbook...${NC}"
echo ""

# Run the playbook
ansible-playbook -i dynamic_inventory.py playbook.yml -v

echo ""
echo "=========================================="
echo "Ansible Configuration Complete!"
echo "=========================================="
echo ""
echo "The infrastructure has been provisioned and configured."
echo ""
echo "Note: Since we're using Localstack, the actual NGINX installation"
echo "is simulated. In a real AWS environment, NGINX would be fully"
echo "installed and accessible."
echo ""
echo "=========================================="

cd ..

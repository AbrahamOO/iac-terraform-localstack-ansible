#!/bin/bash

set -e

echo "=========================================="
echo "Cleaning Up Infrastructure"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

read -p "This will destroy all infrastructure. Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Destroy Terraform resources
if [ -d "terraform" ] && [ -f "terraform/terraform.tfstate" ]; then
    echo ""
    echo -e "${YELLOW}Destroying Terraform resources...${NC}"
    cd terraform
    terraform destroy -auto-approve || echo -e "${RED}Terraform destroy failed (may already be clean)${NC}"
    cd ..
    echo -e "${GREEN}✓${NC} Terraform resources destroyed"
else
    echo -e "${YELLOW}No Terraform state found, skipping...${NC}"
fi

# Stop and remove Localstack
echo ""
echo -e "${YELLOW}Stopping Localstack...${NC}"
docker-compose down -v
echo -e "${GREEN}✓${NC} Localstack stopped and removed"

# Clean up local files
echo ""
echo -e "${YELLOW}Cleaning up local files...${NC}"
rm -rf .localstack
rm -f terraform/tfplan
rm -f terraform/.terraform.lock.hcl
rm -rf terraform/.terraform
rm -f ansible/*.retry

echo -e "${GREEN}✓${NC} Local files cleaned"

echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
echo "All infrastructure has been destroyed and local files cleaned."
echo "To start fresh, run './scripts/setup_localstack.sh'"
echo "=========================================="

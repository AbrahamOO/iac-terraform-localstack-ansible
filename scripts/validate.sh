#!/bin/bash

set -e

echo "=========================================="
echo "Validation and Security Check"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track validation results
ERRORS=0
WARNINGS=0

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo ""
echo -e "${BLUE}Checking prerequisites...${NC}"

# Check required tools
for tool in terraform ansible-playbook docker aws python3; do
    if command_exists "$tool"; then
        echo -e "${GREEN}✓${NC} $tool is installed"
    else
        echo -e "${RED}✗${NC} $tool is NOT installed"
        ((ERRORS++))
    fi
done

echo ""
echo -e "${BLUE}Validating Terraform configuration...${NC}"

if command_exists terraform; then
    cd terraform

    # Format check
    if terraform fmt -check -recursive; then
        echo -e "${GREEN}✓${NC} Terraform files are properly formatted"
    else
        echo -e "${YELLOW}⚠${NC} Terraform files need formatting (run: terraform fmt)"
        ((WARNINGS++))
    fi

    # Validation check
    terraform init -backend=false >/dev/null 2>&1
    if terraform validate; then
        echo -e "${GREEN}✓${NC} Terraform configuration is valid"
    else
        echo -e "${RED}✗${NC} Terraform validation failed"
        ((ERRORS++))
    fi

    cd ..
else
    echo -e "${YELLOW}⚠${NC} Skipping Terraform validation (not installed)"
fi

echo ""
echo -e "${BLUE}Validating Ansible configuration...${NC}"

if command_exists ansible-playbook; then
    cd ansible

    # Syntax check for playbooks
    for playbook in *.yml; do
        if [ -f "$playbook" ]; then
            if ansible-playbook --syntax-check "$playbook" >/dev/null 2>&1; then
                echo -e "${GREEN}✓${NC} $playbook syntax is valid"
            else
                echo -e "${RED}✗${NC} $playbook has syntax errors"
                ((ERRORS++))
            fi
        fi
    done

    # Check dynamic inventory script
    if [ -x "dynamic_inventory.py" ]; then
        echo -e "${GREEN}✓${NC} Dynamic inventory script is executable"
    else
        echo -e "${YELLOW}⚠${NC} Dynamic inventory script is not executable"
        ((WARNINGS++))
    fi

    cd ..
else
    echo -e "${YELLOW}⚠${NC} Skipping Ansible validation (not installed)"
fi

echo ""
echo -e "${BLUE}Checking for security issues...${NC}"

# Check for exposed secrets in files
SECRET_PATTERNS=("password" "secret" "api_key" "private_key" "access_key")
for pattern in "${SECRET_PATTERNS[@]}"; do
    results=$(grep -r -i "$pattern" --exclude-dir=.git --exclude="*.md" --exclude="validate.sh" . | grep -v "description\|comment\|example\|placeholder" | grep -v "var\." || true)
    if [ -n "$results" ]; then
        echo -e "${YELLOW}⚠${NC} Found potential secrets containing '$pattern'"
        echo "$results" | head -n 3
        ((WARNINGS++))
    fi
done

# Check for hardcoded IPs
if grep -r "0.0.0.0/0" terraform/ --include="*.tf" | grep -q "cidr_blocks"; then
    echo -e "${YELLOW}⚠${NC} Found 0.0.0.0/0 in security group rules (acceptable for demo, restrict in production)"
fi

# Check for encryption settings
if grep -q 'encrypted.*=.*true' terraform/main.tf; then
    echo -e "${GREEN}✓${NC} Encryption is enabled for resources"
else
    echo -e "${YELLOW}⚠${NC} Check encryption settings"
    ((WARNINGS++))
fi

# Check for IMDSv2
if grep -q 'http_tokens.*=.*"required"' terraform/main.tf; then
    echo -e "${GREEN}✓${NC} IMDSv2 is enforced on EC2 instances"
else
    echo -e "${RED}✗${NC} IMDSv2 is not enforced"
    ((ERRORS++))
fi

echo ""
echo -e "${BLUE}Checking file permissions...${NC}"

# Check script permissions
for script in scripts/*.sh; do
    if [ -x "$script" ]; then
        echo -e "${GREEN}✓${NC} $script is executable"
    else
        echo -e "${RED}✗${NC} $script is not executable"
        ((ERRORS++))
    fi
done

# Check for overly permissive files
find . -type f -perm 0777 ! -path "./.git/*" | while read -r file; do
    echo -e "${YELLOW}⚠${NC} $file has 777 permissions (too permissive)"
    ((WARNINGS++))
done

echo ""
echo -e "${BLUE}Checking documentation...${NC}"

# Check for required documentation files
for doc in README.md SECURITY.md; do
    if [ -f "$doc" ]; then
        echo -e "${GREEN}✓${NC} $doc exists"
    else
        echo -e "${RED}✗${NC} $doc is missing"
        ((ERRORS++))
    fi
done

# Check .gitignore
if [ -f ".gitignore" ]; then
    required_ignores=("*.tfstate" "*.pem" ".env" ".terraform")
    for ignore in "${required_ignores[@]}"; do
        if grep -q "$ignore" .gitignore; then
            echo -e "${GREEN}✓${NC} .gitignore includes $ignore"
        else
            echo -e "${YELLOW}⚠${NC} .gitignore missing $ignore"
            ((WARNINGS++))
        fi
    done
fi

echo ""
echo -e "${BLUE}Docker validation...${NC}"

if command_exists docker; then
    if docker info >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Docker is running"

        # Validate docker-compose.yml
        if [ -f "docker-compose.yml" ]; then
            echo -e "${GREEN}✓${NC} docker-compose.yml exists"
        else
            echo -e "${RED}✗${NC} docker-compose.yml is missing"
            ((ERRORS++))
        fi
    else
        echo -e "${YELLOW}⚠${NC} Docker is installed but not running"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗${NC} Docker is not installed"
    ((ERRORS++))
fi

echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo -e "Errors: ${RED}$ERRORS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Validation passed!${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ There are $WARNINGS warnings to review${NC}"
    fi
    exit 0
else
    echo -e "${RED}✗ Validation failed with $ERRORS errors${NC}"
    exit 1
fi

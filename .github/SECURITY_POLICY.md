# Security Policy

## Supported Versions

This project is currently in active development. Security updates will be applied to the following versions:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| develop | :white_check_mark: |

## Reporting a Vulnerability

We take the security of this Infrastructure as Code project seriously. If you discover a security vulnerability, please follow these steps:

### Private Disclosure

**DO NOT** open a public issue for security vulnerabilities.

1. **GitHub Security Advisories** (Preferred):
   - Go to the [Security tab](https://github.com/AbrahamOO/iac-terraform-localstack-ansible/security)
   - Click "Report a vulnerability"
   - Fill out the advisory form with details

2. **Email**:
   - Contact the maintainers directly
   - Use encrypted email if possible
   - Include "SECURITY" in the subject line

### What to Include

Please provide as much information as possible:

- **Type of vulnerability**: (e.g., code injection, credential exposure, insecure configuration)
- **Location**: File path and line number if applicable
- **Impact**: What could an attacker potentially achieve?
- **Reproduction**: Step-by-step instructions to reproduce the issue
- **Suggested fix**: If you have a solution in mind
- **Tools used**: For discovery (e.g., scanner name and version)

### Example Report

```
Subject: SECURITY - Insecure S3 Bucket Configuration

Type: Misconfiguration
Location: terraform/main.tf:100-107
Impact: S3 bucket allows public read access, potentially exposing sensitive data

Steps to reproduce:
1. Apply Terraform configuration
2. Check bucket policy with: aws s3api get-bucket-acl --bucket [bucket-name]
3. Observe public read permissions

Suggested fix:
Add aws_s3_bucket_public_access_block resource with all options set to true

CVE: (if applicable)
```

## Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial assessment**: Within 7 days
- **Fix development**: Depends on severity
  - Critical: 1-3 days
  - High: 7 days
  - Medium: 14 days
  - Low: 30 days
- **Public disclosure**: After fix is released

## Severity Classification

We use the CVSS (Common Vulnerability Scoring System) to assess severity:

### Critical (CVSS 9.0-10.0)
- Remote code execution
- Full system compromise
- Credential theft affecting all users

### High (CVSS 7.0-8.9)
- Privilege escalation to admin
- Data exfiltration
- Widespread DoS

### Medium (CVSS 4.0-6.9)
- Limited privilege escalation
- Information disclosure
- Partial service disruption

### Low (CVSS 0.1-3.9)
- Minor information leaks
- Configuration issues with limited impact

## Security Best Practices

When contributing to this project:

### 1. Never Commit Secrets
- No passwords, API keys, or private keys
- Use `.env` files (listed in `.gitignore`)
- Use secrets management tools (AWS Secrets Manager, Vault)

### 2. Review Before Committing
```bash
# Scan for secrets before committing
git diff --cached | grep -i "password\|secret\|key"

# Use tools like gitleaks or trufflehog
gitleaks detect --source . --verbose
```

### 3. Follow Security Guidelines
- Read [SECURITY.md](../SECURITY.md) thoroughly
- Enable IMDSv2 for EC2 instances
- Use encryption at rest for all storage
- Apply principle of least privilege
- Keep dependencies updated

### 4. Infrastructure Security
- Always restrict security groups (avoid 0.0.0.0/0 for SSH)
- Enable VPC Flow Logs in production
- Use private subnets for applications
- Enable CloudTrail for audit logging

### 5. Code Review Requirements
- All PRs require at least one approval
- Security-sensitive changes require maintainer review
- Automated security scans must pass

## Security Features

This project implements:

✅ **Infrastructure Security**
- VPC isolation with security groups
- IMDSv2 enforcement on EC2
- Encrypted EBS volumes and S3 buckets
- Network ACLs for defense in depth

✅ **Access Control**
- SSH key-based authentication only
- Restrictive security group rules
- IAM roles (no hardcoded credentials)

✅ **Monitoring & Detection**
- Optional VPC Flow Logs
- CloudWatch monitoring
- Fail2Ban for intrusion prevention

✅ **Automated Security**
- GitHub Actions security scanning
- Dependency vulnerability checks (Trivy)
- Terraform security analysis (tfsec, Checkov)
- Secret detection (TruffleHog)

## Vulnerability Disclosure

### Public Disclosure Policy

After a vulnerability is fixed:

1. **Security advisory** published on GitHub
2. **CVE assigned** (if applicable)
3. **Release notes** include security details
4. **Credit given** to reporter (unless anonymous)

### Hall of Fame

We recognize security researchers who help improve this project:

(To be updated as vulnerabilities are reported and fixed)

## Compliance

This project aims to align with:

- **CIS Benchmarks**: AWS Foundations
- **NIST**: Cybersecurity Framework
- **OWASP**: Top 10 security risks
- **AWS Well-Architected**: Security pillar

## Security Tools

We use these tools in our CI/CD pipeline:

- **TruffleHog**: Secret detection
- **tfsec**: Terraform static analysis
- **Checkov**: Infrastructure as code scanning
- **Trivy**: Vulnerability scanning
- **Bandit**: Python security linter
- **ansible-lint**: Ansible best practices

## Contact

For security-related questions:
- Open a GitHub Security Advisory
- Check existing security documentation
- Review closed security issues

## Updates

This security policy is reviewed quarterly and updated as needed.

Last updated: 2025-12-03

# Security Best Practices & Documentation

This document outlines the security measures implemented in this Infrastructure as Code project and provides guidance for maintaining a secure deployment.

## Table of Contents

1. [Security Architecture](#security-architecture)
2. [Terraform Security](#terraform-security)
3. [Ansible Security](#ansible-security)
4. [Network Security](#network-security)
5. [Data Protection](#data-protection)
6. [Access Control](#access-control)
7. [Monitoring & Logging](#monitoring--logging)
8. [Compliance Considerations](#compliance-considerations)
9. [Security Checklist](#security-checklist)
10. [Incident Response](#incident-response)

## Security Architecture

### Defense in Depth Strategy

This project implements multiple layers of security:

1. **Network Layer**: VPC isolation, security groups, NACLs
2. **Compute Layer**: Hardened EC2 instances with IMDSv2
3. **Data Layer**: Encrypted storage (EBS, S3)
4. **Application Layer**: NGINX with security headers
5. **Access Layer**: SSH hardening, key-based authentication

### Threat Model

Primary threats addressed:
- Unauthorized access (network and application)
- Data breaches and exfiltration
- DDoS and resource exhaustion
- Configuration drift
- Supply chain attacks

## Terraform Security

### Infrastructure Security Features

#### 1. VPC and Network Isolation

```hcl
# VPC with DNS support enabled
resource "aws_vpc" "main" {
  enable_dns_hostnames = true  # Required for internal DNS
  enable_dns_support   = true  # Security best practice
}
```

#### 2. Security Groups (Least Privilege)

- **Ingress Rules**: Only necessary ports (22, 80, 443)
- **SSH Access**: Configurable CIDR blocks (restrict in production)
- **Egress Rules**: Specific protocols (HTTPS, HTTP, DNS) instead of allow-all

**Production Recommendation**:
```hcl
variable "allowed_ssh_cidr" {
  default = ["YOUR_OFFICE_IP/32"]  # Replace 0.0.0.0/0
}
```

#### 3. EC2 Instance Security

**IMDSv2 Enforcement** (prevents SSRF attacks):
```hcl
metadata_options {
  http_tokens                 = "required"  # IMDSv2 only
  http_put_response_hop_limit = 1
}
```

**Encrypted Root Volume**:
```hcl
root_block_device {
  encrypted = true  # Encryption at rest
}
```

**Monitoring Enabled**:
```hcl
monitoring = true  # Detailed CloudWatch metrics
```

#### 4. S3 Security

- **Public Access Blocked**: All public access disabled by default
- **Encryption at Rest**: AES-256 server-side encryption
- **Versioning**: Enabled for data recovery
- **Lifecycle Policies**: Automatic cleanup of old versions

#### 5. VPC Flow Logs (Optional)

Enable with `enable_flow_logs = true` to capture:
- Accepted connections
- Rejected connections
- All traffic patterns

Useful for:
- Security analysis
- Troubleshooting
- Compliance auditing

### State File Security

**Critical**: Terraform state files contain sensitive data.

#### Localstack (Development)
- State stored in local S3 (simulated)
- Acceptable for development only

#### Production AWS
1. **Enable State Encryption**:
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state"
    encrypt        = true  # Enable encryption
    dynamodb_table = "terraform-locks"  # Enable state locking
    kms_key_id     = "arn:aws:kms:..."  # Use KMS key
  }
}
```

2. **Enable State Locking**:
```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

3. **Restrict State Bucket Access**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::your-terraform-state/*",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
```

### Secrets Management

**Never commit secrets to version control.**

Use one of these approaches:

1. **AWS Secrets Manager** (Recommended):
```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/password"
}
```

2. **HashiCorp Vault**:
```hcl
provider "vault" {
  address = "https://vault.example.com"
}

data "vault_generic_secret" "api_key" {
  path = "secret/api_key"
}
```

3. **Environment Variables**:
```bash
export TF_VAR_db_password="$(aws secretsmanager get-secret-value --secret-id prod/db/password --query SecretString --output text)"
```

## Ansible Security

### Configuration Management Security

#### 1. Dynamic Inventory Security

The dynamic inventory script:
- Reads Terraform outputs (not state directly)
- Uses local execution (no remote API calls in this setup)
- No credentials stored in inventory

#### 2. Connection Security

**For Real AWS Deployments**:
```yaml
vars:
  ansible_user: ubuntu
  ansible_ssh_private_key_file: ~/.ssh/id_rsa
  ansible_connection: ssh
  ansible_ssh_common_args: '-o StrictHostKeyChecking=yes'
```

**Key Management**:
- Use SSH keys, never passwords
- Rotate keys regularly (every 90 days)
- Use different keys per environment
- Store keys securely (AWS Systems Manager Parameter Store)

#### 3. Privilege Escalation

```yaml
become: yes
become_method: sudo
become_user: root
```

**Production Best Practice**:
- Use specific sudo rules (not NOPASSWD)
- Log all sudo commands
- Audit privilege escalation regularly

### Security Hardening Playbook

Run `security-hardening.yml` to apply:

#### System Hardening
- Automatic security updates enabled
- Unnecessary services disabled
- Secure file permissions on sensitive files

#### Network Security
- UFW firewall configured
- Fail2Ban for intrusion prevention
- Rate limiting on SSH

#### SSH Hardening
- Root login disabled
- Password authentication disabled
- Key-based authentication only
- Connection timeouts configured
- Maximum authentication attempts limited

#### Kernel Hardening
- IP forwarding disabled
- ICMP redirects disabled
- SYN cookies enabled
- Source routing disabled
- IPv6 disabled (if not used)

### Ansible Vault for Secrets

For sensitive variables:

```bash
# Create encrypted file
ansible-vault create secrets.yml

# Edit encrypted file
ansible-vault edit secrets.yml

# Run playbook with vault
ansible-playbook playbook.yml --ask-vault-pass
```

Example encrypted variables:
```yaml
# secrets.yml (encrypted)
db_password: "super_secret_password"
api_key: "your_api_key"
ssl_certificate_key: |
  -----BEGIN PRIVATE KEY-----
  ...
  -----END PRIVATE KEY-----
```

## Network Security

### Security Group Rules

#### Production SSH Restriction

```hcl
# Restrict to bastion host or VPN
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/8"]  # Internal only
}
```

#### Application Load Balancer Pattern

```hcl
# ALB security group (internet-facing)
resource "aws_security_group" "alb" {
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Web server security group (ALB only)
resource "aws_security_group" "web" {
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
}
```

### Network ACLs (NACLs)

Implemented as an additional security layer:
- Stateless firewall at subnet level
- Default deny with explicit allows
- Protection against port scanning

### Private Subnet Pattern (Recommended)

```hcl
# Public subnet: Only load balancers
resource "aws_subnet" "public" {
  map_public_ip_on_launch = true
}

# Private subnet: Application servers
resource "aws_subnet" "private" {
  map_public_ip_on_launch = false
}

# NAT Gateway for private subnet internet access
resource "aws_nat_gateway" "main" {
  subnet_id = aws_subnet.public.id
}
```

## Data Protection

### Encryption at Rest

#### S3 Buckets
- **Server-Side Encryption**: AES-256 (SSE-S3) or KMS (SSE-KMS)
- **Bucket Key**: Enabled to reduce KMS costs
- **Versioning**: Enabled for data recovery

#### EBS Volumes
- **Default Encryption**: All volumes encrypted
- **KMS Keys**: Use customer-managed keys for compliance
- **Snapshots**: Automatically encrypted

### Encryption in Transit

#### NGINX SSL/TLS Configuration

For production, configure SSL:

```nginx
server {
    listen 443 ssl http2;
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    # Strong SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

## Access Control

### IAM Best Practices

1. **Principle of Least Privilege**
   ```hcl
   resource "aws_iam_policy" "app" {
     policy = jsonencode({
       Version = "2012-10-17"
       Statement = [{
         Effect   = "Allow"
         Action   = ["s3:GetObject", "s3:PutObject"]
         Resource = ["${aws_s3_bucket.app.arn}/*"]
       }]
     })
   }
   ```

2. **Use IAM Roles (Not Access Keys)**
   ```hcl
   resource "aws_iam_instance_profile" "web" {
     role = aws_iam_role.web.name
   }
   ```

3. **Enable MFA for Human Users**
   ```json
   {
     "Condition": {
       "BoolIfExists": {
         "aws:MultiFactorAuthPresent": "true"
       }
     }
   }
   ```

4. **Rotate Credentials Regularly**
   - Service account passwords: 90 days
   - SSH keys: 90 days
   - IAM access keys: 90 days (prefer roles)

### SSH Key Management

```bash
# Generate a strong SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# For AWS EC2
aws ec2 import-key-pair --key-name my-key \
  --public-key-material fileb://~/.ssh/id_ed25519.pub

# Store private key securely
chmod 600 ~/.ssh/id_ed25519
```

## Monitoring & Logging

### CloudWatch Logs

Enable comprehensive logging:

```hcl
# Application logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/app/${var.project_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
}
```

### Security Monitoring

Implement these AWS services:

1. **AWS Config**: Track configuration changes
2. **AWS CloudTrail**: API call auditing
3. **Amazon GuardDuty**: Threat detection
4. **AWS Security Hub**: Centralized security findings

### Log Analysis

Monitor for:
- Failed authentication attempts
- Privilege escalation attempts
- Unusual network traffic patterns
- Configuration changes
- Access to sensitive resources

## Compliance Considerations

### Common Frameworks

#### PCI DSS
- Encrypt data at rest and in transit
- Implement network segmentation
- Maintain audit logs
- Regular security testing

#### HIPAA
- Enable encryption (S3, EBS)
- Implement access controls
- Enable CloudTrail logging
- BAA with AWS

#### SOC 2
- Document security controls
- Implement monitoring
- Regular vulnerability scans
- Incident response procedures

### Compliance Automation

```hcl
# AWS Config rule for encrypted volumes
resource "aws_config_config_rule" "encrypted_volumes" {
  name = "encrypted-volumes"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }
}
```

## Security Checklist

### Pre-Deployment

- [ ] Review and restrict security group rules
- [ ] Enable encryption on all data stores
- [ ] Configure VPC Flow Logs
- [ ] Set up CloudTrail logging
- [ ] Enable GuardDuty
- [ ] Review IAM policies (least privilege)
- [ ] Rotate all credentials
- [ ] Enable MFA for all users
- [ ] Configure backup and recovery procedures
- [ ] Set up monitoring and alerting

### Post-Deployment

- [ ] Run security scanning tools
- [ ] Verify firewall rules
- [ ] Test backup restoration
- [ ] Review access logs
- [ ] Validate encryption is active
- [ ] Test incident response procedures
- [ ] Document architecture and access procedures
- [ ] Conduct security training for team

### Regular Maintenance

- [ ] Weekly: Review CloudWatch alarms
- [ ] Weekly: Check for failed authentications
- [ ] Monthly: Rotate credentials
- [ ] Monthly: Review IAM permissions
- [ ] Monthly: Patch systems
- [ ] Quarterly: Security audit
- [ ] Quarterly: Penetration testing
- [ ] Annually: Disaster recovery drill

## Incident Response

### Preparation

1. **Document Procedures**: Maintain runbooks for common incidents
2. **Contact List**: Emergency contacts, stakeholders
3. **Tools Access**: Ensure IR team has necessary permissions
4. **Backup Verification**: Regular restore tests

### Detection & Analysis

```bash
# Check recent authentication failures
grep "Failed password" /var/log/auth.log

# Check active connections
netstat -tunap | grep ESTABLISHED

# Review CloudTrail for suspicious API calls
aws cloudtrail lookup-events --lookup-attributes \
  AttributeKey=EventName,AttributeValue=DeleteBucket
```

### Containment

1. **Isolate Compromised Resources**
   ```bash
   # Remove instance from security group
   aws ec2 modify-instance-attribute \
     --instance-id i-1234567890abcdef0 \
     --groups sg-isolation
   ```

2. **Snapshot for Forensics**
   ```bash
   aws ec2 create-snapshot \
     --volume-id vol-1234567890abcdef0 \
     --description "Forensic snapshot"
   ```

3. **Rotate Credentials**
   ```bash
   # Disable compromised credentials
   aws iam update-access-key --access-key-id AKIAI... \
     --status Inactive
   ```

### Recovery

1. Restore from known-good backup
2. Apply patches and security updates
3. Verify security controls
4. Monitor for re-infection

### Post-Incident

1. Document incident timeline
2. Conduct root cause analysis
3. Update security controls
4. Share lessons learned
5. Update incident response procedures

## Additional Resources

- [AWS Security Best Practices](https://aws.amazon.com/security/best-practices/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [Terraform Security Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

## Contact

For security concerns or to report vulnerabilities, please create a security advisory in the GitHub repository.

---

**Remember**: Security is not a one-time effort but an ongoing process. Regularly review and update your security posture.

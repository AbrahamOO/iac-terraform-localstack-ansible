# Infrastructure as Code: Terraform + Ansible + Localstack

I built this project to show how modern infrastructure automation works in practice. Everything here runs on your laptop using Localstack, so you can tear things apart, break stuff, and rebuild without touching your credit card.

## Why This Exists

Over the past few years, I've worked with enough cloud infrastructure to know that the best way to learn is by doing. But AWS bills add up fast when you're experimenting. That's where this project comes in - it's a full IaC pipeline that costs exactly zero dollars to run. You get Terraform for provisioning, Ansible for configuration, and Localstack simulating AWS services locally.

I use this as my testing ground for new automation patterns and as a reference when building production systems. If you're prepping for DevOps interviews, learning infrastructure-as-code, or just want to see how these tools fit together, this project has you covered.

## What This Does

This project provisions a complete infrastructure stack:

- **VPC and Networking**: Creates a VPC, subnet, internet gateway, and routing tables
- **Compute**: Provisions an EC2 instance with proper security groups
- **Storage**: Sets up S3 buckets (including one for Terraform remote state)
- **Configuration**: Uses Ansible with dynamic inventory to configure the instance and deploy NGINX
- **State Management**: Demonstrates Terraform remote state using S3 backend

All of this runs locally using Localstack, a fully functional AWS cloud emulator.

## The Stack

- **Terraform**: Infrastructure provisioning and state management
- **Ansible**: Configuration management with dynamic inventory
- **Localstack**: Local AWS cloud simulation
- **Docker**: Container runtime for Localstack
- **Python**: Dynamic inventory script

## Project Structure

```
iac-terraform-localstack-ansible/
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # Resource definitions
│   ├── variables.tf       # Input variables
│   ├── outputs.tf         # Output values for Ansible
│   ├── provider.tf        # AWS provider configuration
│   └── backend.tf         # Remote state configuration
├── ansible/               # Configuration management
│   ├── dynamic_inventory.py  # Pulls hosts from Terraform
│   ├── playbook.yml       # NGINX installation playbook
│   └── ansible.cfg        # Ansible settings
├── scripts/               # Automation scripts
│   ├── setup_localstack.sh   # Start Localstack and prep S3
│   ├── apply_terraform.sh    # Run Terraform workflow
│   ├── run_ansible.sh        # Execute Ansible playbook
│   └── cleanup.sh            # Tear everything down
├── docker-compose.yml     # Localstack container definition
└── README.md              # You are here
```

## Prerequisites

Before you start, make sure you have these installed:

- **Docker Desktop** (running)
- **Terraform** (>= 1.0)
- **Ansible** (>= 2.9)
- **Python 3** (>= 3.7)
- **AWS CLI** (for Localstack S3 bucket creation)

You can verify everything is installed:

```bash
docker --version
terraform --version
ansible --version
python3 --version
aws --version
```

## Quick Start (Localstack - Free!)

### Step 1: Start Localstack

Fire up the Localstack container and create the S3 bucket for Terraform state:

```bash
chmod +x scripts/*.sh
./scripts/setup_localstack.sh
```

This will:
- Start Localstack in a Docker container
- Wait for services to be ready
- Create an S3 bucket named `terraform-state`

### Step 2: Provision Infrastructure

Run Terraform to create your infrastructure:

```bash
./scripts/apply_terraform.sh
```

This will:
- Initialize Terraform with the S3 backend
- Show you the execution plan
- Prompt for confirmation
- Create VPC, subnet, security groups, and EC2 instance
- Store state in Localstack S3

### Step 3: Configure with Ansible

Deploy and configure NGINX on your instance:

```bash
./scripts/run_ansible.sh
```

This will:
- Pull instance details from Terraform outputs
- Generate dynamic inventory
- Run the Ansible playbook
- Install and configure NGINX

### Step 4: Verify

Check that everything worked:

```bash
# View Terraform state
cd terraform && terraform state list

# View Ansible inventory
cd ansible && ./dynamic_inventory.py --list

# Check Terraform outputs
cd terraform && terraform output
```

### Step 5: Cleanup

When you're done, tear everything down:

```bash
./scripts/cleanup.sh
```

This destroys all resources, stops Localstack, and cleans up local files.

## Understanding the Dynamic Inventory

The magic happens in `ansible/dynamic_inventory.py`. This script:

1. Runs `terraform output -json` to get infrastructure details
2. Extracts the EC2 instance IP and metadata
3. Formats it as Ansible inventory JSON
4. Allows Ansible to target freshly-provisioned instances automatically

You can test it directly:

```bash
cd ansible
chmod +x dynamic_inventory.py
./dynamic_inventory.py --list
```

## Remote State with Localstack

The `backend.tf` file configures Terraform to store state in a Localstack S3 bucket:

```hcl
terraform {
  backend "s3" {
    bucket   = "terraform-state"
    key      = "infra/terraform.tfstate"
    region   = "us-east-1"
    endpoint = "http://localhost:4566"
    ...
  }
}
```

This simulates how you'd use remote state in production. You can inspect the state:

```bash
aws --endpoint-url=http://localhost:4566 s3 ls s3://terraform-state/infra/
```

## Using Real AWS (Optional)

Want to run this on actual AWS infrastructure? Here's how:

### 1. Update Provider Configuration

Edit `terraform/provider.tf` and remove the Localstack-specific settings:

```hcl
provider "aws" {
  region = var.aws_region
  # Remove: access_key, secret_key, skip_* settings, and endpoints block
}
```

### 2. Update Backend Configuration

Edit `terraform/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "your-real-terraform-state-bucket"  # Use your bucket name
    key    = "infra/terraform.tfstate"
    region = "us-east-1"
    # Remove: endpoint, access_key, secret_key, skip_* settings
  }
}
```

### 3. Set AWS Credentials

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### 4. Create the State Bucket

```bash
aws s3 mb s3://your-real-terraform-state-bucket
```

### 5. Update Variables

Set `localstack_endpoint = ""` in `terraform/variables.tf` or pass it via command line.

### 6. Run Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 7. Update Ansible for Real SSH

Edit `ansible/playbook.yml` to use real SSH instead of local connection:

```yaml
vars:
  ansible_user: ubuntu
  ansible_ssh_private_key_file: ~/.ssh/your-key.pem
  ansible_connection: ssh  # Change from 'local'
```

### 8. Run Ansible

```bash
cd ansible
ansible-playbook -i dynamic_inventory.py playbook.yml
```

### Important Notes for AWS

- You'll incur charges for EC2, VPC, and data transfer
- Make sure to destroy resources when done: `terraform destroy`
- Use appropriate AMI IDs for your region (update `variables.tf`)
- Ensure your SSH key is configured in AWS and referenced in Terraform

## How It All Fits Together

1. **Docker Compose** starts Localstack, simulating AWS services
2. **Terraform** provisions infrastructure and stores state in simulated S3
3. **Terraform outputs** provide instance details in JSON format
4. **Dynamic inventory script** transforms Terraform outputs into Ansible inventory
5. **Ansible** connects to the instance and configures it based on the playbook
6. **NGINX** gets installed and configured with a custom landing page

## Troubleshooting

### Localstack not starting

```bash
docker-compose down -v
docker-compose up -d
docker-compose logs -f
```

### Terraform state issues

```bash
cd terraform
terraform init -reconfigure
```

### Ansible can't find hosts

```bash
cd ansible
./dynamic_inventory.py --list
cd ../terraform
terraform output
```

### Port conflicts

If port 4566 is already in use, stop the conflicting service:

```bash
lsof -i :4566
kill -9 <PID>
```

## Key Takeaways

Working through this project taught me a lot about production infrastructure patterns:

- **Remote State**: In real environments, multiple people need to coordinate changes. Remote state prevents conflicts and gives you a single source of truth.
- **Dynamic Inventory**: Manually updating Ansible inventory files is error-prone and tedious. Pulling host info directly from Terraform outputs keeps everything in sync automatically.
- **Idempotency**: Running the same Terraform or Ansible code multiple times produces the same result. This is crucial for reliable automation.
- **Local Testing**: Localstack lets you test infrastructure changes without AWS costs or the risk of breaking production.
- **Security Hardening**: The included security configurations (encrypted volumes, IMDSv2, restrictive security groups) show what production-ready infrastructure actually looks like.

## Next Steps

Some ideas for extending this project:

- Add Terraform modules for reusability
- Implement multi-region deployments
- Add Packer for custom AMI creation
- Integrate Vault for secrets management
- Add monitoring with Prometheus/Grafana
- Implement blue-green deployment patterns
- Add CI/CD pipeline with GitHub Actions

## Found a Bug?

If something's broken or could be better, open an issue. Pull requests welcome too.

## Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [Localstack Documentation](https://docs.localstack.cloud/)
- [AWS Provider for Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## License

This project is open source and available for anyone to use, modify, and learn from.

---

Built this while learning infrastructure automation. Hope it helps you too.

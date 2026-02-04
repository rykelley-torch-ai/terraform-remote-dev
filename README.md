# Remote Development Machine on AWS EC2

This project provides infrastructure-as-code for spinning up a fully configured remote development machine on AWS EC2 using Terraform/Terragrunt for provisioning and Ansible for configuration management.

## Features

- **EC2 Instance**: Ubuntu 24.04 LTS on t3.large (configurable)
- **Security**: SSH-only access restricted to your IP, encrypted EBS volume
- **Development Tools**:
  - **Python**: pyenv, Python 3.11/3.12, poetry, pip, pipx
  - **Go**: Go 1.22+, gopls, golangci-lint, delve
  - **Docker**: Docker CE, Docker Compose v2
  - **DevOps**: Terraform (tfenv), Terragrunt, AWS CLI v2, Azure CLI, Packer, Ansible
  - **Kubernetes**: kubectl, helm, k9s, kubectx/kubens
  - **Shell**: zsh with oh-my-zsh, tmux, vim/neovim
  - **Utilities**: git, jq, ripgrep, fzf, htop, and more

## Prerequisites

Before you begin, ensure you have the following installed locally:

1. **AWS CLI** configured with credentials (`~/.aws/credentials` or environment variables)
2. **Terraform** >= 1.5 ([install](https://developer.hashicorp.com/terraform/downloads))
3. **Terragrunt** >= 0.50 ([install](https://terragrunt.gruntwork.io/docs/getting-started/install/))
4. **Ansible** >= 2.15 ([install](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html))
5. **SSH Key Pair** at `~/.ssh/id_rsa.pub` (or configure a different path)

## AWS Profile Configuration

**Important**: Before running any Terragrunt commands, ensure you're using the correct AWS profile.

### Option 1: Export Environment Variable (Recommended)

```bash
# Set for current terminal session
export AWS_PROFILE=your-profile-name

# Verify you're using the correct account
aws sts get-caller-identity
```

### Option 2: Use AWS_PROFILE Inline

```bash
AWS_PROFILE=your-profile-name terragrunt apply
```

### Option 3: Set Default Profile

```bash
# In ~/.aws/config
[default]
region = us-east-2

[profile your-profile-name]
region = us-east-2
```

### Verify Your Account

Always verify you're in the correct account before deploying:

```bash
# Check current identity
aws sts get-caller-identity

# Expected output shows Account ID
{
    "UserId": "AIDAEXAMPLE",
    "Account": "123456789012",  # <-- Verify this is correct
    "Arn": "arn:aws:iam::123456789012:user/your-user"
}
```

## Quick Start

### 1. Set AWS Profile

```bash
# Set your AWS profile
export AWS_PROFILE=your-profile-name

# Verify correct account
aws sts get-caller-identity
```

### 2. Clone and Navigate

```bash
cd terraform-remote-dev
```

### 3. Review Configuration

Edit the Terragrunt configuration if needed:

```bash
# Edit instance configuration (instance type, volume size, etc.)
vim environments/dev/remote-dev/terragrunt.hcl
```

### 4. Deploy the Instance

```bash
cd environments/dev/remote-dev
terragrunt init
terragrunt apply
```

This will:
- Create an SSH key pair in AWS
- Create a security group allowing SSH from your current IP
- Launch an EC2 instance with Ubuntu 24.04

### 5. Provision with Ansible

After the instance is running, provision it with all development tools:

```bash
# From the project root
./scripts/provision.sh
```

Or run specific roles:

```bash
./scripts/provision.sh --tags "docker,python"
```

### 6. Connect

```bash
# Using the helper script
./scripts/connect.sh

# Or directly via SSH
ssh ubuntu@<INSTANCE_IP>
```

Get the instance IP:

```bash
cd environments/dev/remote-dev
terragrunt output public_ip
```

## VS Code Remote SSH Setup

1. Get the SSH config from Terragrunt output:

```bash
cd environments/dev/remote-dev
terragrunt output vscode_ssh_config
```

2. Add the output to your `~/.ssh/config` file

3. In VS Code, use Remote-SSH extension to connect to host `remote-dev`

## Project Structure

```
terraform-remote-dev/
├── terragrunt.hcl                 # Root Terragrunt config
├── environments/
│   └── dev/
│       ├── env.hcl                # Environment variables
│       ├── terraform-backend/     # S3 backend for state (deploy first)
│       │   └── terragrunt.hcl
│       └── remote-dev/
│           └── terragrunt.hcl     # Instance-specific config
├── modules/
│   ├── terraform-backend/         # S3 + DynamoDB for state management
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── remote-dev-instance/       # Terraform module
│       ├── main.tf                # EC2, security group, key pair
│       ├── variables.tf           # Input variables
│       ├── outputs.tf             # Instance IP, SSH command
│       └── data.tf                # VPC/subnet lookups
├── ansible/
│   ├── ansible.cfg                # Ansible configuration
│   ├── playbooks/
│   │   └── provision-dev.yml      # Main provisioning playbook
│   └── roles/
│       ├── common/                # Base packages, zsh, vim, tmux
│       ├── docker/                # Docker CE, Compose
│       ├── python/                # pyenv, poetry
│       ├── golang/                # Go installation
│       ├── devops-tools/          # Terraform, Terragrunt, AWS CLI
│       ├── azure-cli/             # Azure CLI
│       └── kubernetes/            # kubectl, helm, k9s
├── scripts/
│   ├── connect.sh                 # Quick SSH connect
│   ├── provision.sh               # Run Ansible provisioning
│   ├── destroy.sh                 # Destroy the instance
│   └── update-ssh-ip.sh           # Update security group with new IP
└── README.md
```

## Helper Scripts

| Script | Description |
|--------|-------------|
| `scripts/connect.sh` | SSH into the remote instance |
| `scripts/connect.sh -v` | SSH with verbose output for debugging |
| `scripts/connect.sh --troubleshoot` | Run full SSH diagnostics |
| `scripts/provision.sh` | Run Ansible to configure the instance |
| `scripts/provision.sh --tags docker` | Run only specific Ansible roles |
| `scripts/destroy.sh` | Destroy the EC2 instance |
| `scripts/update-ssh-ip.sh` | Update security group when your IP changes |
| `scripts/troubleshoot.sh` | Diagnose SSH connection problems |

## Remote State Setup (Recommended)

By default, Terraform state is stored locally. For team collaboration and state durability, you can enable remote state storage in S3 with DynamoDB locking.

### 1. Deploy the Backend Infrastructure

```bash
cd environments/dev/terraform-backend
terragrunt init
terragrunt apply
```

This creates:
- **S3 Bucket**: `remote-dev-terraform-state-dev` (versioned, encrypted, private)
- **DynamoDB Table**: `remote-dev-terraform-locks` (for state locking)

### 2. Enable Remote State

Edit `terragrunt.hcl` in the project root and set:

```hcl
# Around line 22
use_remote_state = true
```

### 3. Migrate Existing State (if you already deployed resources)

For each module that has existing local state:

```bash
cd environments/dev/remote-dev
terragrunt init -migrate-state
```

Terragrunt will prompt you to confirm the migration from local to S3.

### Backend Features

| Feature | Description |
|---------|-------------|
| Versioning | All state changes are versioned for recovery |
| Encryption | AES-256 server-side encryption |
| Locking | DynamoDB prevents concurrent modifications |
| Lifecycle | Old versions auto-deleted after 90 days |
| PITR | Point-in-time recovery enabled on DynamoDB |

## Customization

### Change Instance Type

Edit `environments/dev/remote-dev/terragrunt.hcl`:

```hcl
inputs = {
  instance_type = "t3.xlarge"  # More CPU/memory
  root_volume_size = 100        # Larger disk
}
```

### Use a Different SSH Key

```hcl
inputs = {
  ssh_public_key_path = "~/.ssh/my-custom-key.pub"
}
```

### Allow SSH from Specific IPs

```hcl
inputs = {
  allowed_ssh_cidr_blocks = ["203.0.113.0/24", "10.0.0.0/8"]
}
```

### Use Elastic IP (Persistent IP)

```hcl
inputs = {
  use_elastic_ip = true
}
```

### Modify Installed Tools

Edit the Ansible role defaults:

```bash
# Python versions
vim ansible/roles/python/defaults/main.yml

# Go version
vim ansible/roles/golang/defaults/main.yml

# Terraform/Terragrunt versions
vim ansible/roles/devops-tools/defaults/main.yml
```

## Ansible Tags

Run specific parts of the provisioning:

```bash
# Only Docker
./scripts/provision.sh --tags docker

# Multiple tags
./scripts/provision.sh --tags "docker,python,golang"

# Everything except Kubernetes
./scripts/provision.sh --skip-tags kubernetes
```

Available tags:
- `common`, `base` - Basic packages, shell setup
- `docker`, `containers` - Docker and Compose
- `python`, `development` - Python, pyenv, poetry
- `golang`, `go` - Go language
- `devops`, `terraform`, `aws` - DevOps tools (AWS CLI, Terraform, Terragrunt)
- `azure`, `cloud` - Azure CLI
- `kubernetes`, `k8s` - Kubernetes tools

## Cost Estimation

| Resource | Cost (us-east-2) |
|----------|------------------|
| t3.large on-demand | ~$0.0832/hour (~$60/month 24/7) |
| 50GB gp3 EBS | ~$4/month |
| Elastic IP (attached) | Free |
| S3 state bucket | < $0.10/month |
| DynamoDB locks table | < $0.10/month (pay-per-request) |
| **Total** | **~$65/month** running continuously |

**Tip**: Stop the instance when not in use to save costs:

```bash
# Stop instance (preserves data)
aws ec2 stop-instances --instance-ids $(terragrunt output -raw instance_id)

# Start instance
aws ec2 start-instances --instance-ids $(terragrunt output -raw instance_id)
```

## Troubleshooting

### SSH Connection Issues

Run the troubleshooting script for a full diagnostic:

```bash
./scripts/connect.sh --troubleshoot
```

Or use verbose mode to see what's happening:

```bash
./scripts/connect.sh -v
```

### Common SSH Problems

**1. "Connection refused" or "Connection timed out"**

Your IP has likely changed since you ran `terragrunt apply`:

```bash
# Update security group with your current IP
./scripts/update-ssh-ip.sh
```

**2. "Permission denied (publickey)"**

SSH key mismatch. Check which key was used:

```bash
# See which key the instance expects
cd environments/dev/remote-dev
terragrunt output ssh_command

# Make sure you have the matching private key
ls -la ~/.ssh/id_rsa
```

**3. Instance not responding**

The instance may still be initializing (takes 2-3 minutes after launch):

```bash
# Check instance state
cd environments/dev/remote-dev
aws ec2 describe-instances \
  --instance-ids $(terragrunt output -raw instance_id) \
  --query 'Reservations[0].Instances[0].State.Name'
```

**4. Wrong AWS account**

Verify you're querying the right account:

```bash
export AWS_PROFILE=your-profile-name
aws sts get-caller-identity
```

### Ansible Fails on First Run

The instance may still be initializing. Wait a minute and retry:

```bash
./scripts/provision.sh
```

### Permission Denied (Docker)

After provisioning, log out and back in for group changes to take effect:

```bash
# On the remote instance
exit
./scripts/connect.sh
docker ps  # Should work now
```

## Cleanup

Destroy all resources:

```bash
./scripts/destroy.sh
# Or manually:
cd environments/dev/remote-dev
terragrunt destroy
```

If using remote state, destroy the backend **last** (after all other resources):

```bash
cd environments/dev/terraform-backend
terragrunt destroy
```

**Warning**: Destroying the backend will delete all state history. Make sure all other resources are destroyed first.

## Security Notes

- SSH access is restricted to your current IP by default
- Root EBS volume is encrypted
- IMDSv2 is required (more secure instance metadata)
- No password authentication - SSH keys only

## License

MIT

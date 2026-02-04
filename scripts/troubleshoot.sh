#!/bin/bash
#
# Troubleshoot SSH connection issues
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}SSH Connection Troubleshooter${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check AWS identity
echo -e "${BLUE}1. Checking AWS Identity...${NC}"
if aws sts get-caller-identity --output table 2>/dev/null; then
    echo -e "${GREEN}   AWS credentials OK${NC}"
else
    echo -e "${RED}   ERROR: AWS credentials not configured${NC}"
    echo -e "${YELLOW}   Run: export AWS_PROFILE=your-profile-name${NC}"
    exit 1
fi
echo ""

# Get instance info from Terragrunt
echo -e "${BLUE}2. Getting instance information...${NC}"
cd "$PROJECT_ROOT/environments/dev/remote-dev"

if ! INSTANCE_IP=$(terragrunt output -raw public_ip 2>/dev/null); then
    echo -e "${RED}   ERROR: Could not get instance IP${NC}"
    echo -e "${YELLOW}   Run: cd environments/dev/remote-dev && terragrunt apply${NC}"
    exit 1
fi

INSTANCE_ID=$(terragrunt output -raw instance_id 2>/dev/null || echo "unknown")
ALLOWED_CIDRS=$(terragrunt output -json allowed_ssh_cidrs 2>/dev/null || echo "[]")

echo -e "${GREEN}   Instance ID: ${INSTANCE_ID}${NC}"
echo -e "${GREEN}   Public IP: ${INSTANCE_IP}${NC}"
echo -e "${GREEN}   Allowed SSH CIDRs: ${ALLOWED_CIDRS}${NC}"
echo ""

# Check instance state
echo -e "${BLUE}3. Checking instance state...${NC}"
INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "unknown")
echo -e "   Instance state: ${INSTANCE_STATE}"

if [ "$INSTANCE_STATE" != "running" ]; then
    echo -e "${RED}   ERROR: Instance is not running (state: ${INSTANCE_STATE})${NC}"
    if [ "$INSTANCE_STATE" == "stopped" ]; then
        echo -e "${YELLOW}   Start it with: aws ec2 start-instances --instance-ids ${INSTANCE_ID}${NC}"
    fi
    exit 1
fi
echo -e "${GREEN}   Instance is running${NC}"
echo ""

# Get current public IP
echo -e "${BLUE}4. Checking your current IP...${NC}"
MY_IP=$(curl -s https://checkip.amazonaws.com 2>/dev/null || curl -s https://ifconfig.me 2>/dev/null || echo "unknown")
echo -e "   Your current IP: ${MY_IP}"

# Check if IP is in allowed CIDRs
if echo "$ALLOWED_CIDRS" | grep -q "$MY_IP"; then
    echo -e "${GREEN}   Your IP is in the allowed list${NC}"
else
    echo -e "${RED}   WARNING: Your IP (${MY_IP}) may not be in the security group!${NC}"
    echo -e "${YELLOW}   The security group allows: ${ALLOWED_CIDRS}${NC}"
    echo -e "${YELLOW}   Run: ./scripts/update-ssh-ip.sh to fix this${NC}"
fi
echo ""

# Check SSH key
echo -e "${BLUE}5. Checking SSH key...${NC}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
SSH_PUB_KEY="${SSH_KEY}.pub"

if [ -f "$SSH_KEY" ]; then
    echo -e "${GREEN}   Private key exists: ${SSH_KEY}${NC}"
else
    echo -e "${RED}   ERROR: Private key not found: ${SSH_KEY}${NC}"
    echo -e "${YELLOW}   Generate one with: ssh-keygen -t rsa -b 4096${NC}"
    exit 1
fi

if [ -f "$SSH_PUB_KEY" ]; then
    echo -e "${GREEN}   Public key exists: ${SSH_PUB_KEY}${NC}"
else
    echo -e "${RED}   WARNING: Public key not found: ${SSH_PUB_KEY}${NC}"
fi

# Check key permissions
KEY_PERMS=$(stat -f "%OLp" "$SSH_KEY" 2>/dev/null || stat -c "%a" "$SSH_KEY" 2>/dev/null)
if [ "$KEY_PERMS" == "600" ] || [ "$KEY_PERMS" == "400" ]; then
    echo -e "${GREEN}   Key permissions OK (${KEY_PERMS})${NC}"
else
    echo -e "${YELLOW}   WARNING: Key permissions are ${KEY_PERMS}, should be 600${NC}"
    echo -e "${YELLOW}   Fix with: chmod 600 ${SSH_KEY}${NC}"
fi
echo ""

# Test network connectivity
echo -e "${BLUE}6. Testing network connectivity...${NC}"
if nc -z -w5 "$INSTANCE_IP" 22 2>/dev/null; then
    echo -e "${GREEN}   Port 22 is reachable${NC}"
else
    echo -e "${RED}   ERROR: Cannot reach port 22 on ${INSTANCE_IP}${NC}"
    echo -e "${YELLOW}   Possible causes:${NC}"
    echo -e "${YELLOW}   - Your IP is not in the security group (run ./scripts/update-ssh-ip.sh)${NC}"
    echo -e "${YELLOW}   - Instance is still initializing (wait a minute)${NC}"
    echo -e "${YELLOW}   - Network/firewall blocking outbound SSH${NC}"
fi
echo ""

# Test SSH connection with verbose output
echo -e "${BLUE}7. Testing SSH connection...${NC}"
echo -e "${YELLOW}   Running: ssh -v -o ConnectTimeout=10 ubuntu@${INSTANCE_IP}${NC}"
echo ""

ssh -v -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -i "$SSH_KEY" \
    ubuntu@"$INSTANCE_IP" "echo 'SSH connection successful!'" 2>&1 | head -50

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Troubleshooting Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "If SSH is failing, try these in order:"
echo ""
echo "1. Update security group with your current IP:"
echo -e "   ${YELLOW}./scripts/update-ssh-ip.sh${NC}"
echo ""
echo "2. Wait for instance to fully initialize (2-3 minutes after launch)"
echo ""
echo "3. Manually test SSH with verbose output:"
echo -e "   ${YELLOW}ssh -vvv -i ~/.ssh/id_rsa ubuntu@${INSTANCE_IP}${NC}"
echo ""
echo "4. Check security group in AWS Console:"
echo -e "   ${YELLOW}https://console.aws.amazon.com/ec2/v2/home?region=us-east-2#SecurityGroups:${NC}"
echo ""

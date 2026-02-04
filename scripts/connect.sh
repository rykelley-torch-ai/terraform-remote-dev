#!/bin/bash
#
# Connect to the remote development instance via SSH
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Fetching instance IP from Terragrunt...${NC}"

# Get the public IP from Terragrunt output
cd "$PROJECT_ROOT/environments/dev/remote-dev"

if ! IP=$(terragrunt output -raw public_ip 2>/dev/null); then
    echo -e "${RED}Error: Could not get public IP from Terragrunt.${NC}"
    echo -e "${YELLOW}Make sure you have run 'terragrunt apply' first.${NC}"
    exit 1
fi

if [ -z "$IP" ]; then
    echo -e "${RED}Error: Public IP is empty. Instance may not be running.${NC}"
    exit 1
fi

# Get SSH key path from Terragrunt or use default
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"

echo -e "${GREEN}Connecting to remote-dev instance at ${IP}...${NC}"
echo ""

# Connect via SSH
ssh -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ubuntu@"$IP" "$@"

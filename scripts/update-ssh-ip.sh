#!/bin/bash
#
# Update the security group to allow SSH from your current IP
# Useful when your IP changes (e.g., working from a different location)
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

echo -e "${GREEN}Updating security group with your current IP...${NC}"
echo ""

# Get current public IP
CURRENT_IP=$(curl -s https://checkip.amazonaws.com)
echo -e "${BLUE}Your current IP: ${CURRENT_IP}${NC}"
echo ""

cd "$PROJECT_ROOT/environments/dev/remote-dev"

# Run Terragrunt apply to update the security group
# The module automatically detects your IP
echo -e "${GREEN}Applying Terraform changes...${NC}"
terragrunt apply -auto-approve

echo ""
echo -e "${GREEN}Security group updated successfully!${NC}"
echo -e "${GREEN}You should now be able to SSH to your instance.${NC}"

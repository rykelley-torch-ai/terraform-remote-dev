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
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
VERBOSE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        --troubleshoot)
            exec "$SCRIPT_DIR/troubleshoot.sh"
            ;;
        --help)
            echo "Usage: $0 [OPTIONS] [SSH_ARGS]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose     Enable verbose SSH output"
            echo "  --troubleshoot    Run full troubleshooting diagnostics"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

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

# Get SSH key path from environment or use default
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH private key not found: ${SSH_KEY}${NC}"
    echo -e "${YELLOW}Generate one with: ssh-keygen -t rsa -b 4096${NC}"
    echo -e "${YELLOW}Or set SSH_KEY environment variable to your key path${NC}"
    exit 1
fi

echo -e "${GREEN}Connecting to remote-dev instance at ${IP}...${NC}"
echo -e "${BLUE}Using SSH key: ${SSH_KEY}${NC}"
echo ""

# Connect via SSH
ssh $VERBOSE -i "$SSH_KEY" \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ubuntu@"$IP" "$@"

# If SSH failed, suggest troubleshooting
if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}SSH connection failed.${NC}"
    echo -e "${YELLOW}Run: ./scripts/connect.sh --troubleshoot${NC}"
    echo -e "${YELLOW}Or:  ./scripts/update-ssh-ip.sh (if your IP changed)${NC}"
fi

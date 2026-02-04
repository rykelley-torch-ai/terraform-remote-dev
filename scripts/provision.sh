#!/bin/bash
#
# Provision the remote development instance using Ansible
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
ANSIBLE_ARGS=""
TAGS=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --tags)
            TAGS="$2"
            shift 2
            ;;
        --check)
            ANSIBLE_ARGS="$ANSIBLE_ARGS --check"
            shift
            ;;
        --diff)
            ANSIBLE_ARGS="$ANSIBLE_ARGS --diff"
            shift
            ;;
        -v|-vv|-vvv|-vvvv)
            ANSIBLE_ARGS="$ANSIBLE_ARGS $1"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --tags TAGS     Run only specific tags (e.g., 'docker,python')"
            echo "  --check         Run in check mode (dry run)"
            echo "  --diff          Show differences when changing files"
            echo "  -v/-vv/-vvv     Increase verbosity"
            echo ""
            echo "Available tags:"
            echo "  common, base, docker, containers, python, golang, go,"
            echo "  development, devops, terraform, aws, kubernetes, k8s"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Remote Development Instance Provisioning${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}Error: ansible-playbook not found.${NC}"
    echo -e "${YELLOW}Install Ansible: pip install ansible${NC}"
    exit 1
fi

# Get the public IP from Terragrunt output
echo -e "${BLUE}Fetching instance IP from Terragrunt...${NC}"
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

echo -e "${GREEN}Target IP: ${IP}${NC}"
echo ""

# Wait for SSH to be available
echo -e "${BLUE}Waiting for SSH to be available...${NC}"
MAX_RETRIES=30
RETRY_COUNT=0
while ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@"$IP" "echo 'SSH is ready'" &>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "${RED}Error: SSH not available after ${MAX_RETRIES} attempts.${NC}"
        exit 1
    fi
    echo -e "${YELLOW}Waiting for SSH... (attempt ${RETRY_COUNT}/${MAX_RETRIES})${NC}"
    sleep 10
done
echo -e "${GREEN}SSH is available!${NC}"
echo ""

# Change to ansible directory
cd "$PROJECT_ROOT/ansible"

# Build Ansible command
ANSIBLE_CMD="ansible-playbook -i '$IP,' playbooks/provision-dev.yml"

if [ -n "$TAGS" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD --tags '$TAGS'"
fi

if [ -n "$ANSIBLE_ARGS" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD $ANSIBLE_ARGS"
fi

echo -e "${BLUE}Running: ${ANSIBLE_CMD}${NC}"
echo ""

# Run Ansible playbook
eval $ANSIBLE_CMD

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Provisioning complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Connect to your instance: ${BLUE}$PROJECT_ROOT/scripts/connect.sh${NC}"
echo -e "Or directly: ${BLUE}ssh ubuntu@${IP}${NC}"

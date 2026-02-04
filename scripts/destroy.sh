#!/bin/bash
#
# Destroy the remote development instance
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}WARNING: This will destroy your remote dev instance!${NC}"
echo -e "${YELLOW}============================================${NC}"
echo ""

read -p "Are you sure you want to destroy the instance? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${GREEN}Aborted.${NC}"
    exit 0
fi

cd "$PROJECT_ROOT/environments/dev/remote-dev"

echo ""
echo -e "${RED}Destroying remote development instance...${NC}"
echo ""

terragrunt destroy -auto-approve

echo ""
echo -e "${GREEN}Instance destroyed successfully.${NC}"

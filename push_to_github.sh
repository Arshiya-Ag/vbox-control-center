#!/usr/bin/env bash
# ==============================================================================
# Helper to connect and push VirtualBox Control Center to GitHub
# ==============================================================================
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${REPO_DIR}"

echo -e "${CYAN}${BOLD}==> GitHub Push Helper for VirtualBox Control Center${NC}\n"

if [ -n "${1:-}" ]; then
    REMOTE_URL="$1"
else
    echo -e "Please enter your GitHub repository URL (HTTPS or SSH):"
    echo -e "Example: ${YELLOW}https://github.com/your-username/vbox-control-center.git${NC}"
    echo -e "     or: ${YELLOW}git@github.com:your-username/vbox-control-center.git${NC}"
    read -rp "Repo URL: " REMOTE_URL
fi

if [ -z "${REMOTE_URL}" ]; then
    echo -e "${RED}Error: Repository URL cannot be empty.${NC}"
    exit 1
fi

# Add or update origin
if git remote | grep -q "^origin$"; then
    echo -e "Updating existing 'origin' remote..."
    git remote set-url origin "${REMOTE_URL}"
else
    echo -e "Adding 'origin' remote..."
    git remote add origin "${REMOTE_URL}"
fi

echo -e "Ensuring branch is set to 'main'..."
git branch -M main

echo -e "\n${CYAN}Pushing to GitHub (${REMOTE_URL})...${NC}"
git push -u origin main

echo -e "\n${GREEN}${BOLD}✔ Successfully pushed to GitHub!${NC}\n"

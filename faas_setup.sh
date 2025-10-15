#!/bin/bash
# Faas Setup Script for Linux (Custom from your GitHub account)
# Author: You
# Usage: sudo bash faas_setup.sh


set -e

GITHUB_ACCOUNT="bitresearch2006"     # Your GitHub username
FAASD_REPO="faasd"

echo "[1/3] 🛠️ Installing dependencies and configuring Docker..."
sudo apt update
sudo apt install -y curl git docker.io

sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker "$USER"
echo "User '$USER' added to the docker group. Please re-login for this change to fully apply."

echo "[2/3] 🚀 Downloading and running install.sh from your forked repo using download_with_retry..."

curl -sSL "https://raw.githubusercontent.com/$GITHUB_ACCOUNT/$FAASD_REPO/master/hack/install.sh" -o install.sh
chmod +x install.sh
sudo bash install.sh

echo "[3/3] Checking installations..."
docker --version
faas-cli version

if sudo systemctl is-active faasd --quiet; then
    echo "✅ faasd service is running."
else
    echo "❌ faasd service failed to start. Check logs with: sudo journalctl -u faasd -xe"
    exit 1
fi

echo "✅ OpenFaaS (faasd + faas-cli) setup complete!"
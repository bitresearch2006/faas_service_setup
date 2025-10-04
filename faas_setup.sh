#!/bin/bash
# Faas Setup Script for Linux (Custom from your GitHub account)
# Author: You
# Usage: sudo bash faas_setup.sh

set -e

# -------------------------
# --- CONFIGURATION ---
# -------------------------
GITHUB_ACCOUNT="bitresearch2006"     # Your GitHub username
FAAS_CLI_REPO="faas-cli"             # Repository for faas-cli
FAASD_REPO="faasd"                   # Repository for faasd
BIN_DIR="/usr/local/bin"

# -------------------------
# --- 1. Install Dependencies ---
# -------------------------
echo "[1/5] Installing dependencies..."
sudo apt update
sudo apt install -y curl git docker.io

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# -------------------------
# --- 2. Install faasd from your GitHub ---
# -------------------------
echo "[2/5] Installing faasd from your GitHub repo..."
LATEST_FAASD=$(curl -sI https://github.com/$GITHUB_ACCOUNT/$FAASD_REPO/releases/latest | grep -i "location:" | awk -F"/" '{print $NF}' | tr -d '\r')
echo "Latest faasd version: $LATEST_FAASD"

curl -sSL https://github.com/$GITHUB_ACCOUNT/$FAASD_REPO/releases/download/$LATEST_FAASD/faasd > faasd
chmod +x faasd
sudo mv faasd $BIN_DIR/faasd

# -------------------------
# --- 3. Install faas-cli from your GitHub ---
# -------------------------
echo "[3/5] Installing faas-cli from your GitHub repo..."
LATEST_CLI=$(curl -sI https://github.com/$GITHUB_ACCOUNT/$FAAS_CLI_REPO/releases/latest | grep -i "location:" | awk -F"/" '{print $NF}' | tr -d '\r')
echo "Latest faas-cli version: $LATEST_CLI"

curl -sSL https://github.com/$GITHUB_ACCOUNT/$FAAS_CLI_REPO/releases/download/$LATEST_CLI/faas-cli > faas-cli
chmod +x faas-cli
sudo mv faas-cli $BIN_DIR/faas-cli

# -------------------------
# --- 4. Initialize faasd ---
# -------------------------
echo "[4/5] Installing and starting faasd..."
sudo systemctl disable --now openfaas || true   # in case installed previously
sudo faasd install

# -------------------------
# --- 5. Confirm Installation ---
# -------------------------
echo "[5/5] Checking installations..."
docker --version
faas-cli version
faasd --version

echo "✅ OpenFaaS (faasd + faas-cli) setup complete!"

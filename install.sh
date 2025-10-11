#!/bin/bash
# Faas Setup Script for Linux (Custom from your GitHub account)
# Author: You
# Usage: sudo bash faas_setup.sh


set -e

# -------------------------
# --- CONFIGURATION ---
# -------------------------
GITHUB_ACCOUNT="bitresearch2006"     # Your GitHub username
FAAS_CLI_REPO="faas-cli"
FAASD_REPO="faasd"
BIN_DIR="/usr/local/bin"

# --- Function to get the latest release tag using GitHub API ---
get_latest_tag() {
    local repo_owner=$1
    local repo_name=$2
    # Fetches the latest release, extracts the 'tag_name' field, and cleans it up
    curl -s "https://api.github.com/repos/$repo_owner/$repo_name/releases/latest" | \
    grep -oP '"tag_name":\s*"\K[^"]+' 
}

# -------------------------
# --- 1. Install Dependencies ---
# -------------------------
echo "[1/45] 🛠️ Installing dependencies and configuring Docker..."
sudo apt update
sudo apt install -y curl git docker.io

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add current user to docker group (requires re-login to take effect)
sudo usermod -aG docker "$USER"
echo "User '$USER' added to the docker group. Please re-login for this change to fully apply."

# -------------------------
# --- 2. Install faasd ---
# -------------------------
echo "[2/5] 📦 Installing faasd from your GitHub repo: $GITHUB_ACCOUNT/$FAASD_REPO..."
LATEST_FAASD=$(get_latest_tag "$GITHUB_ACCOUNT" "$FAASD_REPO")

if [ -z "$LATEST_FAASD" ]; then
    echo "ERROR: Could not find latest release tag for $FAASD_REPO. ENSURE a release with assets is published on GitHub. Exiting."
    exit 1
fi

echo "Latest faasd version: $LATEST_FAASD"
# Download the asset file named 'faasd' from the release
curl -sSL "https://github.com/$GITHUB_ACCOUNT/$FAASD_REPO/releases/download/$LATEST_FAASD/faasd" -o "faasd"
chmod +x faasd
sudo mv faasd "$BIN_DIR/faasd"

# -------------------------
# --- 3. Install faas-cli ---
# -------------------------
echo "[3/5] 💻 Installing faas-cli from your GitHub repo: $GITHUB_ACCOUNT/$FAAS_CLI_REPO..."
LATEST_CLI=$(get_latest_tag "$GITHUB_ACCOUNT" "$FAAS_CLI_REPO")

if [ -z "$LATEST_CLI" ]; then
    echo "ERROR: Could not find latest release tag for $FAAS_CLI_REPO. ENSURE a release with assets is published on GitHub. Exiting."
    exit 1
fi

echo "Latest faas-cli version: $LATEST_CLI"
# Download the asset file named 'faas-cli' from the release
curl -sSL "https://github.com/$GITHUB_ACCOUNT/$FAAS_CLI_REPO/releases/download/$LATEST_CLI/faas-cli" -o "faas-cli"
chmod +x faas-cli
sudo mv faas-cli "$BIN_DIR/faas-cli"

# -------------------------
# --- 4. Initialize faasd ---
# -------------------------
# Define the destination directory for faasd configuration
FAASD_CONFIG_DEST="/var/lib/faasd"
HACK_DIR="$FAASD_CONFIG_DEST/hack"

echo "[4/5] ⚙️ Setting up faasd configuration in $FAASD_CONFIG_DEST..."

# 1. Ensure the destination directory and the required 'hack' subdirectory exist
sudo mkdir -p "$FAASD_CONFIG_DEST"
sudo mkdir -p "$HACK_DIR"

# 2. Download the required config files directly from the 'master' branch of your GitHub fork

echo "Downloading configuration files..."

# Configuration files for the root of /var/lib/faasd/
sudo curl -sSL "https://raw.githubusercontent.com/$GITHUB_ACCOUNT/$FAASD_REPO/master/docker-compose.yaml" \
    --output "$FAASD_CONFIG_DEST/docker-compose.yaml"

sudo curl -sSL "https://raw.githubusercontent.com/$GITHUB_ACCOUNT/$FAASD_REPO/master/resolv.conf" \
    --output "$FAASD_CONFIG_DEST/resolv.conf"

sudo curl -sSL "https://raw.githubusercontent.com/$GITHUB_ACCOUNT/$FAASD_REPO/master/prometheus.yml" \
    --output "$FAASD_CONFIG_DEST/prometheus.yml"

# faasd-provider.service required by the installer in the 'hack' subdirectory
sudo curl -sSL "https://raw.githubusercontent.com/$GITHUB_ACCOUNT/$FAASD_REPO/master/hack/faasd-provider.service" \
    --output "$HACK_DIR/faasd-provider.service"

# faasd required by the installer in the 'hack' subdirectory
sudo curl -sSL "https://raw.githubusercontent.com/$GITHUB_ACCOUNT/$FAASD_REPO/master/hack/faasd.service" \
    --output "$HACK_DIR/faasd.service"

echo "[4/5] 🚀 Installing and starting faasd. This may take a moment..."

# Execute the directory change AND install command with root privileges using sudo sh -c
sudo sh -c "
    # Temporarily change directory to where the config files are located
    cd \"$FAASD_CONFIG_DEST\" && 
    # Run the install command from that location
    faasd install
"

echo "faasd installation complete. Check status with: sudo systemctl status faasd"

# --- 5. Confirm Installation ---
# -------------------------
echo "[5/5] Checking installations..."
docker --version
faas-cli version
# faasd --version # REMOVED: This flag is not supported by the binary.

# Check the status of the installed service, which is the most reliable check.
if sudo systemctl is-active faasd --quiet; then
    echo "✅ faasd service is running."
else
    echo "❌ faasd service failed to start. Check logs with: sudo journalctl -u faasd -xe"
    exit 1
fi

echo "✅ OpenFaaS (faasd + faas-cli) setup complete! You may need to log out and log back in to use 'docker' and 'faas-cli' without 'sudo'."
#!/bin/bash
# Faas Setup Script for Linux (Custom from your GitHub account)
# Author: You
# Usage: sudo bash faas_setup.sh

# Exit immediately if a command exits with a non-zero status
set -e

# --- CONFIGURATION ---
GITHUB_ACCOUNT="bitresearch2006"     # Your GitHub username
FAASD_REPO="faasd"
# ---------------------

echo "[1/3] 🛠️ Installing core dependencies..."
sudo apt update
sudo apt install -y curl git docker.io

# --- ADDED: Explicitly create the docker group (only if it doesn't exist) ---
# The '|| true' ensures the script doesn't fail if the group was already created.
sudo groupadd docker || true

# Now, add the user to the group
sudo usermod -aG docker "$USER"
echo "User '$USER' added to the docker group. Please re-login for this change to fully apply."

sudo systemctl enable docker

echo "[2/3] 🚀 Downloading and running the comprehensive OpenFaaS installer..."

# The install.sh script handles: 
# - Installing containerd and CNI
# - Installing faasd and faas-cli binaries
# - Setting up faasd systemd services and configuration
curl -sSL "https://raw.githubusercontent.com/$GITHUB_ACCOUNT/$FAASD_REPO/master/hack/install.sh" -o install.sh
chmod +x install.sh

# Run the full installer script. This handles service configuration and may start containerd.
sudo bash install.sh

echo "[3/3] Starting services and running final checks..."

# Ensure the standard Docker service is running (it depends on containerd, which install.sh sets up)
sudo systemctl enable docker
sudo systemctl start docker

# Check for and start the local registry (only after Docker is confirmed running)
if [ "$(sudo docker ps -aq -f name=registry)" ]; then
  echo "⚠️ A container named 'registry' already exists. Starting it..."
  # Use sudo here because the user may not have re-logged in yet
  sudo docker start registry || sudo docker run -d -p 5000:5000 --restart=always --name registry registry:2
else
  echo "🐳 Starting local Docker registry..."
  sudo docker run -d -p 5000:5000 --restart=always --name registry registry:2
fi


# --- Final Verification ---
echo "Verifying installations..."
docker --version
faas-cli version

# Check if faasd service is running (faasd install usually starts it)
if sudo systemctl is-active faasd --quiet; then
    echo "✅ faasd service is running."
else
    echo "❌ faasd service failed to start. Check logs with: sudo journalctl -u faasd -xe"
    exit 1
fi

echo "✅ OpenFaaS (faasd + faas-cli) setup complete!"

# ==========================================================
# 🔓 AUTOMATED LOGIN: Log in as the user who called the script
# ==========================================================

echo ""
echo "Attempting to log in to OpenFaaS gateway..."

# 1. Ensure the user who called 'sudo' is available
if [ -z "$SUDO_USER" ]; then
    echo "⚠️ Cannot determine the calling user (\$SUDO_USER is empty). Skipping automated login."
else
    # 2. Get the password using 'sudo' (as the file is root-owned)
    # The command runs as root, and its output is captured into a variable.
    LOGIN_PASSWORD=$(sudo cat /var/lib/faasd/secrets/basic-auth-password)

    # 3. Execute the faas-cli login command as the standard user ($SUDO_USER)
    # We pipe the password into the standard user's faas-cli.
    # This saves the token to the standard user's profile (~/.config/faas-cli/config.yml).
    echo "$LOGIN_PASSWORD" | sudo -u "$SUDO_USER" /usr/local/bin/faas-cli login -s
    
    echo "✅ Authentication token saved for user: $SUDO_USER"
fi

# Note: Adding a user to the docker group requires a re-login to take effect.
read -p "Do you want to restart now to apply the change and finalize Docker access? [y/N]: " restart_choice
if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
  echo "🔄 Restarting system..."
  sudo reboot
else
  echo "⏳ Please remember to log out and log back in later."
fi
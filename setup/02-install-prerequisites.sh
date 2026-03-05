#!/bin/bash
# 02-install-prerequisites.sh
# Run this inside WSL (Ubuntu 24.04) to install all ELMFIRE dependencies.
# Usage: bash setup/02-install-prerequisites.sh

set -e  # exit on error

echo "=== Updating package lists ==="
sudo apt-get update && sudo apt-get upgrade -y

echo "=== Installing system packages ==="
sudo apt-get install -y \
    bc \
    csvkit \
    gdal-bin \
    gfortran \
    git \
    jq \
    libopenmpi-dev \
    openmpi-bin \
    pigz \
    python3 \
    python3-pip \
    unzip \
    wget \
    zip

echo "=== Installing Python packages (system-wide) ==="
sudo pip3 install \
    google-api-python-client \
    grpcio \
    grpcio-tools \
    python-dateutil \
    --break-system-packages

echo ""
echo "=== All prerequisites installed successfully ==="
echo "Next step: run  bash setup/03-clone-and-configure.sh"

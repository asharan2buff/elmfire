#!/bin/bash
# 03-clone-and-configure.sh
# Clones the ELMFIRE repository and configures environment variables.
# Run this inside WSL (Ubuntu 24.04).
# Usage: bash setup/03-clone-and-configure.sh

set -e

# ─── Configuration ────────────────────────────────────────────────────────────
ELMFIRE_CLONE_DIR="$HOME/elmfire"
ELMFIRE_SCRATCH_DIR="$HOME/elmfire_scratch"
ELMFIRE_BRANCH="2025.0212"   # latest stable release; change to 'main' for bleeding-edge
# ──────────────────────────────────────────────────────────────────────────────

echo "=== Cloning ELMFIRE (branch: $ELMFIRE_BRANCH) ==="
if [ -d "$ELMFIRE_CLONE_DIR" ]; then
    echo "Directory $ELMFIRE_CLONE_DIR already exists — skipping clone."
else
    git clone --branch "$ELMFIRE_BRANCH" --single-branch \
        https://github.com/lautenberger/elmfire.git \
        "$ELMFIRE_CLONE_DIR"
fi

echo "=== Creating scratch directory ==="
mkdir -p "$ELMFIRE_SCRATCH_DIR"

echo "=== Writing environment variables to ~/.bashrc ==="

# Remove any previous ELMFIRE env block to avoid duplicates
sed -i '/# === ELMFIRE environment variables ===/,/# === end ELMFIRE ===/d' ~/.bashrc

cat >> ~/.bashrc << EOF

# === ELMFIRE environment variables ===
export ELMFIRE_SCRATCH_BASE=$ELMFIRE_SCRATCH_DIR
export ELMFIRE_BASE_DIR=$ELMFIRE_CLONE_DIR
export ELMFIRE_INSTALL_DIR=\$ELMFIRE_BASE_DIR/build/linux/bin
export CLOUDFIRE_SERVER=worldgen.cloudfire.io
export PATH=\$PATH:\$ELMFIRE_INSTALL_DIR:\$ELMFIRE_BASE_DIR/cloudfire
# === end ELMFIRE ===
EOF

echo "=== Sourcing ~/.bashrc ==="
source ~/.bashrc

echo ""
echo "=== Done! Environment configured. ==="
echo ""
echo "Next steps:"
echo "  1. Build ELMFIRE:"
echo "       source ~/.bashrc"
echo "       cd \$ELMFIRE_BASE_DIR/build/linux"
echo "       ./make_gnu.sh"
echo ""
echo "  2. Run Tutorial 03 for California:"
echo "       bash tutorials/03-california-fire/run_sim.sh"

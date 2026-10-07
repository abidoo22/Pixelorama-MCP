#!/usr/bin/env bash
# scripts/start_pixelorama.sh
# Reliably starts Pixelorama with the pix-MCP bridge extension in background daemon mode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Pix-MCP Bridge Launcher ==="

# 1. Kill any existing Pixelorama process
echo "[1/5] Stopping any running Pixelorama instances..."
killall -9 Pixelorama.x86_64 2>/dev/null || true
pkill -9 -f Pixelorama 2>/dev/null || true

# 2. Clean crash recovery and lock files
echo "[2/5] Cleaning crash locks and stale session files..."
rm -f ~/.local/share/pixelorama/.running ~/.local/share/pixelorama/extensions/Monitoring.ini
rm -rf ~/.local/share/pixelorama/give_in_bug_report/*
rm -rf ~/.local/share/pixelorama/backups/*

# 3. Synchronize extension PCK
echo "[3/5] Synchronizing PixMcpBridge.pck to extension folders..."
mkdir -p ~/.local/share/pixelorama/extensions ~/.local/share/pixelorama/Extensions
if [ -f "${ROOT_DIR}/pixelorama-plugin/PixMcpBridge.pck" ]; then
    cp -f "${ROOT_DIR}/pixelorama-plugin/PixMcpBridge.pck" ~/.local/share/pixelorama/extensions/PixMcpBridge.pck
    cp -f "${ROOT_DIR}/pixelorama-plugin/PixMcpBridge.pck" ~/.local/share/pixelorama/Extensions/PixMcpBridge.pck
    if [ -d "/home/abido/Downloads/Pixelorama-Linux-64bit/pixelorama_data/Extensions" ]; then
        cp -f "${ROOT_DIR}/pixelorama-plugin/PixMcpBridge.pck" /home/abido/Downloads/Pixelorama-Linux-64bit/pixelorama_data/Extensions/PixMcpBridge.pck
    fi
fi

# 4. Launch Pixelorama in background daemon mode
PIXELORAMA_BIN="/home/abido/Downloads/Pixelorama-Linux-64bit/Pixelorama.x86_64"
if [ ! -x "${PIXELORAMA_BIN}" ]; then
    echo "Error: Pixelorama binary not found at ${PIXELORAMA_BIN}" >&2
    exit 1
fi

echo "[4/5] Launching Pixelorama daemon..."
setsid "${PIXELORAMA_BIN}" </dev/null >/dev/null 2>&1 &

# 5. Wait and verify /health endpoint
echo "[5/5] Verifying bridge health on port 7373..."
MAX_RETRIES=20
for ((i=1; i<=MAX_RETRIES; i++)); do
    if curl -s http://127.0.0.1:7373/health >/dev/null 2>&1; then
        STATUS=$(curl -s http://127.0.0.1:7373/health)
        echo "✅ Pixelorama bridge is online and healthy!"
        echo "   ${STATUS}"
        exit 0
    fi
    sleep 0.5
done

echo "❌ Failed to connect to bridge at http://127.0.0.1:7373/health after 10s." >&2
exit 1

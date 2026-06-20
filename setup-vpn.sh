#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run this script with sudo"
    exit 1
fi

if [[ $# -lt 1 ]]; then
    echo "Usage: sudo $0 <path-to-ovpn-file>"
    exit 1
fi

OVPN_FILE="$(realpath "$1")"
CON_NAME="$(basename "$OVPN_FILE" .ovpn)"

if ! [[ -f "$OVPN_FILE" ]]; then
    echo "File not found: $OVPN_FILE"
    exit 1
fi

# Remove existing connection if present
nmcli connection delete "$CON_NAME" 2>/dev/null || true

# Import the connection (places certs in system store with proper SELinux context)
nmcli connection import type openvpn file "$OVPN_FILE"

# Split DNS: use VPN DNS (10.8.0.1) only for *.vpn domains
nmcli connection modify "$CON_NAME" \
    ipv4.dns "10.8.0.1" \
    ipv4.dns-search "~vpn" \
    ipv4.dns-priority 100 \
    ipv4.ignore-auto-dns yes

# Split routing: only route 10.8.0.0/24 through VPN, no default gateway
nmcli connection modify "$CON_NAME" \
    ipv4.routes "10.8.0.0/24" \
    ipv4.never-default yes \
    ipv4.ignore-auto-routes yes

# Autoconnect on boot/NM restart
nmcli connection modify "$CON_NAME" \
    connection.autoconnect yes \
    connection.autoconnect-priority 10

echo ""
echo "Done. Connection '$CON_NAME' configured:"
echo "  - Split DNS: 10.8.0.1 for *.vpn domains only"
echo "  - Split routing: only 10.8.0.0/24 via VPN"
echo "  - Autoconnect: enabled"
echo ""
echo "Activating now..."
nmcli connection up "$CON_NAME"

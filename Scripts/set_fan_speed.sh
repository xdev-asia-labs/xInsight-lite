#!/bin/bash
# Set fan speed on Apple Silicon (ADVANCED - requires SIP disabled and sudo)
# Usage: sudo ./set_fan_speed.sh <rpm>
# WARNING: This requires System Integrity Protection (SIP) to be disabled
# and the 'smc' tool to be installed. Use at your own risk.

RPM=$1

if [ -z "$RPM" ]; then
    echo "Error: RPM value required"
    echo "Usage: sudo $0 <rpm>"
    echo "Example: sudo $0 2500"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo"
    exit 1
fi

# Check if smc tool is available
if ! command -v smc &> /dev/null; then
    echo "Error: 'smc' tool not found"
    echo "Please install smc tool from: https://github.com/hholtmann/smcFanControl/tree/master/smc-command"
    exit 1
fi

# Check SIP status
SIP_STATUS=$(csrutil status 2>/dev/null | grep -i "disabled")
if [ -z "$SIP_STATUS" ]; then
    echo "Warning: System Integrity Protection (SIP) appears to be enabled"
    echo "This script requires SIP to be disabled to write to SMC"
    echo "To disable SIP:"
    echo "  1. Restart Mac and hold Command+R to enter Recovery Mode"
    echo "  2. Open Terminal from Utilities menu"
    echo "  3. Run: csrutil disable"
    echo "  4. Restart"
    exit 1
fi

# Convert RPM to hex value for SMC
# F0Ac is the fan 0 actual speed key
HEX=$(printf "%04x" $RPM)

echo "Setting fan speed to ${RPM} RPM (0x${HEX})..."

# Write the value using smc
smc -k "F0Ac" -w "$HEX" 2>&1

if [ $? -eq 0 ]; then
    echo "Fan speed set successfully"
    # Read back to verify
    CURRENT=$(smc -k "F0Ac" -r 2>/dev/null)
    echo "Current setting: $CURRENT"
else
    echo "Error: Failed to set fan speed"
    echo "Make sure you have the correct permissions and SIP is disabled"
    exit 1
fi

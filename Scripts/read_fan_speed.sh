#!/bin/bash
# Helper script to read fan speed on Apple Silicon
# Requires running with sudo for powermetrics access

OUTPUT=$(powermetrics -i 1000 -n 1 --samplers smc 2>/dev/null)

# Extract fan speed
FAN_SPEED=$(echo "$OUTPUT" | grep -i "Fan:" | grep -oE "[0-9]+" | head -1)

if [ -z "$FAN_SPEED" ]; then
    # Try alternative method via thermal
    THERMAL_OUTPUT=$(powermetrics -i 1000 -n 1 --samplers thermal 2>/dev/null)
    
    # Check for fan in thermal output
    FAN_SPEED=$(echo "$THERMAL_OUTPUT" | grep -i "fan\|rpm" | grep -oE "[0-9]+" | head -1)
fi

if [ -z "$FAN_SPEED" ]; then
    echo "0"
else
    echo "$FAN_SPEED"
fi

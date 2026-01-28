#!/bin/bash
# Debug script to run the serial client locally with predefined parameters for testing.

echo "==================================================="
echo "  DEBUG SERIAL CLIENT FOR LOCAL TESTING"
echo "  Empresa: Rzavala"
echo "  Device ID: device-serial-bf05ebcf2c834539b2c63f542754282d"
echo "  Tunnel URL: wss://25e3696d9acd.ngrok-free.app/cable"
echo "  Token: 74bf5e0a6ae8813dfe80593ed84a7a9c"
echo "==================================================="

python3 serial_server_prod.py --url wss://wmsys.fly.dev/cable --token 74bf5e0a6ae8813dfe80593ed84a7a9c --device-id device-serial-bf05ebcf2c834539b2c63f542754282d
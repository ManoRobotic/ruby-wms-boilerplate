#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Debug script to run the serial client locally with predefined parameters for testing.
"""

import subprocess
import sys
import os


def run_debug_client():
    """
    Runs the serial_server_prod.py with debug parameters:
    - Empresa: Rzavala
    - ID Dispositivo: device-serial-bf05ebcf2c834539b2c63f542754282d
    - Token: 74bf5e0a6ae8813dfe80593ed84a7a9c
    - Tunnel: https://25e3696d9acd.ngrok-free.app
    """
    
    # Debug parameters
    empresa = "Rzavala"
    device_id = "device-serial-bf05ebcf2c834539b2c63f542754282d"
    token = "74bf5e0a6ae8813dfe80593ed84a7a9c"
    tunnel_url = "wss://wmsys.fly.dev/cable"  # Note: using wss for WebSocket
    
    print("=" * 60)
    print("🔧 DEBUG SERIAL CLIENT FOR LOCAL TESTING")
    print(f"🏢 Empresa: {empresa}")
    print(f"🆔 Device ID: {device_id}")
    print(f"🔗 Tunnel URL: {tunnel_url}")
    print(f"🔑 Token: {token[:6]}..." + "*" * (len(token) - 6))  # Mask token for security
    print("=" * 60)
    
    # Prepare the command
    cmd = [
        sys.executable,  # Use the same Python interpreter
        "serial_server_prod.py",
        "--url", tunnel_url,
        "--token", token,
        "--device-id", device_id
    ]
    
    print(f"🚀 Executing command: {' '.join(cmd)}")
    print("-" * 60)
    
    try:
        # Run the command
        result = subprocess.run(cmd, check=True)
        print(f"✅ Process exited with code: {result.returncode}")
    except subprocess.CalledProcessError as e:
        print(f"❌ Process failed with code: {e.returncode}")
        print(f"Error output: {e}")
        sys.exit(e.returncode)
    except KeyboardInterrupt:
        print("\n⚠️  Process interrupted by user")
        sys.exit(0)


if __name__ == "__main__":
    run_debug_client()
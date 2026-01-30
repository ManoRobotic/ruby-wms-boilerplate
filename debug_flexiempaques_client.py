#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Debug script to run the serial client locally with Flexiempaques parameters for testing.
"""

import subprocess
import sys
import os


def run_debug_client():
    """
    Runs the serial_server_prod.py with Flexiempaques parameters:
    - Empresa: Flexiempaques
    - ID Dispositivo: device-serial-6bca882ac82e4333afedfb48ac3eea8e
    - Token: f5284e6402cf64f9794711b91282e343
    - Tunnel: https://25e3696d9acd.ngrok-free.app
    """
    
    # Debug parameters
    empresa = "Flexiempaques"
    device_id = "device-serial-6bca882ac82e4333afedfb48ac3eea8e"
    token = "f5284e6402cf64f9794711b91282e343"
    tunnel_url = "wss://25e3696d9acd.ngrok-free.app/cable"  # Note: using wss for WebSocket
    
    print("=" * 60)
    print("🔧 DEBUG SERIAL CLIENT FOR FLEXIEMPAQUES")
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
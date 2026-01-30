#!/bin/bash
# Debug script to run the serial client locally with Flexiempaques parameters for testing.

echo "==================================================="
echo "  DEBUG SERIAL CLIENT FOR FLEXIEMPAQUES"
echo "  Empresa: Flexiempaques"
echo "  Device ID: device-serial-6bca882ac82e4333afedfb48ac3eea8e"
echo "  Tunnel URL: wss://25e3696d9acd.ngrok-free.app/cable"
echo "  Token: f5284e6402cf64f9794711b91282e343"
echo "==================================================="

python3 serial_server_prod.py --url wss://25e3696d9acd.ngrok-free.app/cable --token f5284e6402cf64f9794711b91282e343 --device-id device-serial-6bca882ac82e4333afedfb48ac3eea8e
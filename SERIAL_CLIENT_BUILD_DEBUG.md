# Serial Client Build and Debug Instructions

## Building the Executable

The GitHub Actions workflow automatically builds the executable when changes are pushed to the main branch. The workflow is defined in `.github/workflows/build_exe.yml` and creates a Windows executable using PyInstaller.

## Debugging Locally

For local debugging with the provided test parameters:

### Using Python Script
```bash
python debug_serial_client.py
```

### Using Shell Script (Unix/Linux/macOS)
```bash
./debug_serial_client.sh
```

### Using Batch Script (Windows)
```cmd
debug_serial_client.bat
```

## Test Parameters

- **Empresa**: Rzavala
- **ID Dispositivo**: device-serial-bf05ebcf2c834539b2c63f542754282d
- **Token**: 74bf5e0a6ae8813dfe80593ed84a7a9c
- **Tunnel URL**: wss://25e3696d9acd.ngrok-free.app/cable

## Manual Build

To manually build the executable locally:

```bash
pip install pyinstaller
pyinstaller --onefile --clean --name "simple_wms_serial_server" --hidden-import=win32timezone --hidden-import=win32print final_working_serial_server.py
```

The executable will be created in the `dist/` directory.
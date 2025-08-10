#!/bin/bash

# Script para iniciar el servidor serial Flask
echo "=== Iniciando Servidor Serial para WMS ==="

# Verificar si Python está instalado
if ! command -v python3 &> /dev/null; then
    echo "Error: Python3 no está instalado"
    exit 1
fi

# Verificar si Flask está instalado
if ! python3 -c "import flask" 2>/dev/null; then
    echo "Instalando dependencias..."
    pip3 install -r requirements.txt
fi

# Crear directorio de logs
mkdir -p logs

# Variables de entorno
export FLASK_ENV=development
export PYTHONUNBUFFERED=1

echo "Configuración:"
echo "- Puerto: 5000"
echo "- Modo: desarrollo"
echo "- Host: 0.0.0.0"
echo "- Logs: logs/"

echo ""
echo "Endpoints disponibles:"
echo "  GET  http://localhost:5000/health"
echo "  GET  http://localhost:5000/ports"
echo "  POST http://localhost:5000/scale/connect"
echo "  POST http://localhost:5000/scale/start"
echo "  GET  http://localhost:5000/scale/read"
echo "  POST http://localhost:5000/printer/connect"
echo "  POST http://localhost:5000/printer/print"

echo ""
echo "Iniciando servidor..."
echo "Presiona Ctrl+C para detener"
echo "=================================="

python3 serial_server.py
#!/bin/bash

# Script para iniciar el servidor serial automáticamente
# Este script debe ser ejecutado desde el directorio raíz del proyecto

echo "Iniciando servidor serial..."

# Verificar si el entorno virtual existe
if [ ! -d "venv" ]; then
  echo "Creando entorno virtual..."
  python3 -m venv venv
fi

# Activar el entorno virtual
echo "Activando entorno virtual..."
source venv/bin/activate

# Verificar si las dependencias están instaladas
echo "Verificando dependencias..."
pip install --break-system-packages -r requirements.txt

# Iniciar el servidor serial de producción en segundo plano
echo "Iniciando servidor serial de producción en segundo plano..."
nohup python3 serial_server_prod.py > serial_server.log 2>&1 &

echo "Servidor serial iniciado con PID $!"
echo "Logs disponibles en serial_server.log"
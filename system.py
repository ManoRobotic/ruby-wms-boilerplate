#!/usr/bin/env python3
import subprocess
import time
import requests
import webbrowser
import os

# Configuración
COMPOSE_DIR = ".devcontainer"  # Carpeta donde está docker-compose.yml
RAILS_SERVICE = "wms_system_app-rails-app-1"  # Nombre del contenedor Rails
RAILS_PORT = 3000
RAILS_PATH = "/workspaces/ruby-wms-boilerplate"
FLASK_SCRIPT = "./start_serial_server.sh"

def run_command(cmd):
    """Ejecuta un comando mostrando salida en tiempo real."""
    print(f"Ejecutando: {' '.join(cmd)}")
    result = subprocess.run(cmd, text=True)
    if result.returncode != 0:
        raise SystemExit(f"❌ Error ejecutando {' '.join(cmd)}")

def docker_compose_up():
    """Levanta todos los servicios con docker compose desde la carpeta correcta."""
    print("Levantando servicios de Docker Compose...")
    cwd_actual = os.getcwd()
    os.chdir(COMPOSE_DIR)
    try:
        run_command(["docker", "compose", "up", "-d"])
    finally:
        os.chdir(cwd_actual)

def start_rails():
    """Ejecuta bin/dev dentro del contenedor Rails en foreground para ver logs."""
    print("Iniciando aplicación Rails con bin/dev (modo foreground)...")
    subprocess.run([
        "docker", "exec", "-it", RAILS_SERVICE,
        "bash", "-c", f"cd {RAILS_PATH} && bin/dev"
    ])

def wait_for_rails():
    """Espera a que Rails esté listo."""
    print("Esperando a que Rails inicie...")
    for i in range(60):
        try:
            r = requests.get(f"http://localhost:{RAILS_PORT}")
            print(f"Intento {i+1}: status_code={r.status_code}")
            if r.status_code < 500:
                print("✅ Rails está listo.")
                return
        except requests.exceptions.ConnectionError as e:
            print(f"Intento {i+1}: Error de conexión - {e}")
        time.sleep(1)
    raise TimeoutError("Rails no inició a tiempo.")

def start_flask():
    """Inicia el servidor Flask."""
    print("Iniciando servidor Flask...")
    run_command(["bash", FLASK_SCRIPT])

if __name__ == "__main__":
    docker_compose_up()

    # Ahora arrancamos Rails en foreground para ver su salida y confirmar que está bien
    start_rails()

    # Si llegas acá, Rails terminó (se paró)
    # Si quieres que el script espere Rails antes de abrir navegador y levantar Flask,
    # deberías ejecutar start_rails en otro thread o en background (más complejo).

    # Por ahora, solo podemos abrir navegador y arrancar Flask si este script
    # no se bloquea esperando a Rails.

    try:
        wait_for_rails()
        print(f"Abrriendo navegador en http://localhost:{RAILS_PORT} ...")
        webbrowser.open(f"http://localhost:{RAILS_PORT}")
        start_flask()
        print("✅ Todos los servicios están arriba.")
    except TimeoutError as e:
        print(str(e))

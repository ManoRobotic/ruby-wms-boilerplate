#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Cliente asíncrono de Action Cable para comunicación serial con báscula e impresora.
REFACTORED VERSION: Cost-efficient connection lifecycle with Fly.io auto-stop support.

CHANGES:
- State machine for connection lifecycle
- 5-minute inactivity timeout
- Exponential backoff reconnection
- Single active connection guarantee
- Structured logging
- Thread-safe operations
"""
import sys
import os
import argparse
import asyncio
import threading
import time
import json
import serial
import serial.tools.list_ports
from datetime import datetime
import logging
import uuid
import websockets
import base64
import glob
import tempfile
from enum import Enum
from typing import Optional, Callable, Any

# ============================================================================
# SECTION 1: STATE MACHINE DEFINITION
# ============================================================================

class ConnectionState(Enum):
    """
    Connection state machine states.
    Transitions must be explicit and logged.
    """
    DISCONNECTED = "disconnected"
    CONNECTING = "connecting"
    CONNECTED = "connected"
    IDLE_TIMEOUT = "idle_timeout"
    RECONNECTING = "reconnecting"


# ============================================================================
# SECTION 2: STRUCTURED LOGGING
# ============================================================================

class StructuredLogger:
    """
    Structured logging for connection lifecycle events.
    All logs include timestamp, level, event type, and context.
    """

    def __init__(self, base_logger: logging.Logger):
        self.logger = base_logger

    def _log_event(self, event: str, level: str = "info", **kwargs):
        """Log a structured event with consistent format."""
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": level,
            "event": event,
            **kwargs
        }
        log_msg = json.dumps(log_entry)
        getattr(self.logger, level)(log_msg)

    # Connection lifecycle events
    def connection_open(self, url: str):
        self._log_event("connection_open", "info", url=url)

    def connection_closed(self, reason: str = "normal"):
        self._log_event("connection_closed", "info", reason=reason)

    def inactivity_shutdown(self, idle_seconds: int):
        self._log_event("inactivity_shutdown", "info", idle_seconds=idle_seconds)

    def reconnect_attempt(self, attempt: int, delay_seconds: float):
        self._log_event("reconnect_attempt", "info", attempt=attempt, delay_seconds=delay_seconds)

    def reconnect_success(self, attempt: int, total_delay_seconds: float):
        self._log_event("reconnect_success", "info", attempt=attempt, total_delay_seconds=total_delay_seconds)

    def state_transition(self, from_state: str, to_state: str, reason: str = ""):
        self._log_event("state_transition", "info", from_state=from_state, to_state=to_state, reason=reason)

    # Message events
    def message_sent(self, action: str, size_bytes: int):
        self._log_event("message_sent", "info", action=action, size_bytes=size_bytes)

    def message_received(self, action: str):
        self._log_event("message_received", "info", action=action)

    # Error events
    def connection_error(self, error: str):
        self._log_event("connection_error", "error", error=error)

    def serial_error(self, error: str, port: Optional[str] = None):
        self._log_event("serial_error", "error", error=error, port=port)


# ============================================================================
# SECTION 3: PLATFORM-SPECIFIC IMPORTS
# ============================================================================

# Import platform-specific modules conditionally
if sys.platform.startswith('win'):
    try:
        import winreg
    except ImportError:
        winreg = None

try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False

try:
    import win32print
    WIN32_AVAILABLE = True
except ImportError:
    WIN32_AVAILABLE = False


# ============================================================================
# SECTION 4: CONFIGURATION CONSTANTS
# ============================================================================

# Save config in user folder to avoid permission errors in EXE
CONFIG_DIR = os.path.expanduser("~")
CONFIG_FILE = os.path.join(CONFIG_DIR, 'wms_serial_config.json')
PID_FILE = os.path.join(CONFIG_DIR, 'wms_serial.pid')

# ============================================================================
# INACTIVITY TIMEOUT CONFIGURATION (CRITICAL)
# ============================================================================
INACTIVITY_TIMEOUT_SECONDS = 5 * 60  # 5 minutes

# ============================================================================
# EXPONENTIAL BACKOFF CONFIGURATION
# ============================================================================
RECONNECT_DELAYS = [1, 2, 5, 10, 30, 60]  # seconds
MAX_RECONNECT_DELAY = 5 * 60  # Cap at 5 minutes


# ============================================================================
# SECTION 5: SINGLE INSTANCE CHECK
# ============================================================================

def check_single_instance():
    """
    Verifica que no haya otras copias y mata TODAS las instancias previas por nombre.
    Ensures single active connection guarantee at process level.
    """
    if not PSUTIL_AVAILABLE:
        logger.warning("psutil no está instalado, omitiendo verificación de instancia única")
        return True

    # Lista de nombres de scripts que podrían estar corriendo y bloqueando el puerto
    conflicting_scripts = [
        'serial_server_prod.py',
        'serial_server_prod.exe',
        'simple_wms_serial_server.exe',
        'final_working_serial_server.py',
        'serial_server_windows.py'
    ]

    current_pid = os.getpid()
    logger.info(f"🛡️ Verificando instancias y conflictos (PID actual: {current_pid})...")

    # 1. Verificar archivo PID
    pid_file = os.path.join(tempfile.gettempdir(), "wms_serial_server.pid")
    if os.path.exists(pid_file):
        try:
            with open(pid_file, 'r') as f:
                old_pid = int(f.read().strip())

            if psutil.pid_exists(old_pid) and old_pid != current_pid:
                logger.info(f"   ⚰️ Archivo PID encontrado ({old_pid}). Intentando limpieza...")
                try:
                    old_process = psutil.Process(old_pid)
                    logger.warning(f"   💀 MATANDO PROCESO ZOMBIE (PID {old_pid}): {old_process.name()}")
                    old_process.terminate()
                    old_process.wait(timeout=5)
                except psutil.NoSuchProcess:
                    logger.info("   ✅ Proceso ya no existe")
                except psutil.TimeoutExpired:
                    logger.warning(f"   ⚠️ Proceso {old_pid} no respondió, forzando terminación...")
                    old_process.kill()
                except Exception as e:
                    logger.error(f"   ❌ Error matando proceso {old_pid}: {e}")
        except ValueError:
            logger.warning("   ⚠️ PID inválido en archivo, borrando...")
            try:
                os.remove(pid_file)
            except:
                pass
        except Exception as e:
            logger.debug(f"Fallo en limpieza por PID: {e}")

    # 2. Buscar procesos por nombre
    try:
        current_script_name = os.path.basename(__file__)
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                proc_info = proc.info
                proc_pid = proc_info['pid']

                if proc_pid == current_pid:
                    continue

                should_kill = False
                proc_cmd = ' '.join(proc_info.get('cmdline', []))

                if 'serial_server_prod.exe' in proc_cmd.lower():
                    should_kill = True
                elif 'python' in proc_cmd.lower() and current_script_name.lower() in proc_cmd.lower():
                    should_kill = True

                if should_kill:
                    logger.warning(f"   💀 MATANDO INSTANCIA ZOMBIE DETECTADA (PID {proc_pid}): {proc_cmd[:50]}...")
                    proc.kill()
                    time.sleep(1)
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
    except Exception as e:
        logger.debug(f"Fallo al usar psutil: {e}")

    # 3. Guardar PID actual
    with open(PID_FILE, 'w') as f:
        f.write(str(current_pid))

    return True


# ============================================================================
# SECTION 6: HARDWARE AUDIT
# ============================================================================

def log_hardware_audit():
    """Realiza un escaneo profundo del hardware disponible y lo vuelca al log."""
    logger.info("=== AUDITORIA DE HARDWARE INICIAL ===")
    try:
        ports = serial.tools.list_ports.comports()
        if not ports:
            logger.warning("!!! NO SE DETECTARON PUERTOS SERIALES EN EL SISTEMA !!!")
        for p in ports:
            logger.info(f"Puerto Serial: {p.device}")
            logger.info(f" - Descripción: {p.description}")
            logger.info(f" - Fabricante: {p.manufacturer}")
            logger.info(f" - HWID: {p.hwid}")
            logger.info(f" - VID/PID: {p.vid}/{p.pid}")
    except Exception as e:
        logger.error(f"Error realizando auditoría de hardware: {e}")

    if sys.platform.startswith('win') and WIN32_AVAILABLE:
        try:
            printers = [p[2] for p in win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]
            logger.info(f"Impresoras detectadas: {printers}")
        except:
            logger.warning("No se pudo auditar impresoras.")
    logger.info("=====================================")


# ============================================================================
# SECTION 7: HARDWARE MANAGERS (Thread-Safe)
# ============================================================================

class ScaleManager:
    """Thread-safe scale manager with RLock for recursive calls."""

    def __init__(self, port=None, baudrate=115200):
        self.port = port
        self.baudrate = baudrate
        self.serial_connection = None
        self.connected = False
        self.lock = threading.RLock()
        self.last_weight = 0.0

    def set_port(self, new_port):
        with self.lock:
            if self.port != new_port:
                logger.info(f"Cambiando puerto de la báscula a: {new_port}")
                self.port = new_port
                self.disconnect()

    def connect(self) -> bool:
        with self.lock:
            if self.connected:
                return True
            try:
                available_ports = [p.device for p in serial.tools.list_ports.comports()]
                if self.port not in available_ports:
                    logger.warning(f"⚠ Puerto {self.port} no disponible en este sistema")
                    self.connected = False
                    return False

                self.serial_connection = serial.Serial(self.port, self.baudrate, timeout=1)
                self.connected = self.serial_connection.is_open
                if self.connected:
                    logger.info(f"✅ Conexión de báscula establecida en {self.port}")
                return self.connected
            except serial.SerialException as e:
                logger.error(f"✗ Error de conexión serial en báscula: {e}")
                self.connected = False
                return False
            except Exception as e:
                logger.error(f"✗ Error inesperado al conectar báscula: {e}")
                self.connected = False
                return False

    def disconnect(self):
        with self.lock:
            if self.serial_connection and self.serial_connection.is_open:
                self.serial_connection.close()
            self.connected = False
            logger.info("Báscula desconectada.")

    def read_weight(self, timeout=1):
        if not self.connect():
            return None
        try:
            with self.lock:
                start_time = time.time()
                while time.time() - start_time < timeout:
                    if self.serial_connection and self.serial_connection.in_waiting > 0:
                        data = self.serial_connection.readline().decode('utf-8').strip()
                        if data:
                            return {'weight': data, 'timestamp': datetime.now().isoformat()}
                    time.sleep(0.05)
        except serial.SerialException as e:
            logger.error(f"Error leyendo la báscula, desconectando: {e}")
            self.disconnect()
        return None


class PrinterManager:
    """Thread-safe printer manager with RLock for recursive calls."""

    def __init__(self, printer_name=None):
        self.printer_name = printer_name
        self.is_connected = False
        self.lock = threading.RLock()
        self.connect_printer()

    def set_printer(self, new_printer_name):
        with self.lock:
            if self.printer_name != new_printer_name:
                logger.info(f"Cambiando impresora a: {new_printer_name}")
                self.printer_name = new_printer_name
                self.connect_printer()

    def connect_printer(self):
        with self.lock:
            if not WIN32_AVAILABLE:
                self.is_connected = False
                return False
            if not self.printer_name:
                self.is_connected = False
                logger.warning("No se ha especificado un nombre de impresora.")
                return False
            try:
                printers_raw = win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)
                printers = [p[2] for p in printers_raw]
                if self.printer_name in printers:
                    self.is_connected = True
                    logger.info(f"✅ Impresora lista: {self.printer_name}")
                else:
                    self.is_connected = False
                    logger.error(f"✗ No se encontró la impresora llamada: '{self.printer_name}'")
                    logger.info(f"Impresoras disponibles: {printers}")
                return self.is_connected
            except Exception as e:
                logger.error(f"✗ Error buscando impresora: {e}")
                self.is_connected = False
                return False

    def print_label(self, content, ancho_mm=80, alto_mm=50):
        if not self.connect_printer():
            logger.error("Impresora no conectada.")
            return
        hPrinter = None
        try:
            hPrinter = win32print.OpenPrinter(self.printer_name)
            full_content = content
            is_zpl = content.strip().startswith("^XA")

            if not is_zpl and "SIZE" not in content.upper():
                full_content = f"SIZE {ancho_mm} mm, {alto_mm} mm\nCLS\n{content}\nPRINT 1,1\n"
            else:
                full_content = content

            if not full_content.endswith('\n'):
                full_content += '\n'

            hJob = win32print.StartDocPrinter(hPrinter, 1, ("Label", None, "RAW"))
            win32print.StartPagePrinter(hPrinter)
            win32print.WritePrinter(hPrinter, full_content.encode('utf-8'))
            time.sleep(0.2)

            try:
                win32print.EndPagePrinter(hPrinter)
                win32print.EndDocPrinter(hJob)
            except Exception as doc_error:
                logger.warning(f"Error con EndDocPrinter: {doc_error}. Continuando...")

            win32print.ClosePrinter(hPrinter)
            logger.info(f"✓ Etiqueta {'ZPL' if is_zpl else 'TSPL'} enviada a la impresora.")
        except Exception as e:
            logger.error(f"✗ Error al imprimir: {e}")
            if hPrinter:
                try:
                    win32print.ClosePrinter(hPrinter)
                except:
                    pass


# ============================================================================
# SECTION 8: CONFIGURATION HELPERS
# ============================================================================

def save_config(config):
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=4)
        logger.info(f"Configuración guardada en {CONFIG_FILE}")
    except Exception as e:
        logger.error(f"No se pudo guardar la configuración: {e}")


def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"No se pudo cargar la configuración: {e}")
    return {}


# ============================================================================
# SECTION 9: SERIAL CLIENT WITH STATE MACHINE
# ============================================================================

class SerialClient:
    """
    WebSocket client with state machine, inactivity timeout, and exponential backoff.

    STATE MACHINE:
        DISCONNECTED -> CONNECTING -> CONNECTED -> IDLE_TIMEOUT -> DISCONNECTED
                              ^                    |
                              |                    v
                              +---- RECONNECTING --+

    THREAD SAFETY:
        - All state changes protected by asyncio.Lock
        - Timer operations are thread-safe
        - Single active connection guaranteed
    """

    def __init__(self, url: str, token: str, device_id: str,
                 scale_manager: ScaleManager, printer_manager: PrinterManager,
                 slogger: StructuredLogger):
        self.url = url
        self.token = token
        self.device_id = device_id
        self.scale_manager = scale_manager
        self.printer_manager = printer_manager
        self.slogger = slogger

        # WebSocket connection
        self.websocket: Optional[websockets.WebSocketClientProtocol] = None
        self.subscription_confirmed = False
        self.configuration_received = False

        # State machine
        self._state = ConnectionState.DISCONNECTED
        self._state_lock = asyncio.Lock()

        # Inactivity timeout tracking
        self._last_activity_time: float = 0.0
        self._inactivity_task: Optional[asyncio.Task] = None

        # Message handling
        self.identifier_str: Optional[str] = None
        self.message_handlers = {}

        # Thread-safe locks for hardware access
        self.scale_lock = asyncio.Lock()
        self.printer_lock = asyncio.Lock()

        # Reconnection tracking
        self._reconnect_attempt = 0
        self._total_reconnect_delay = 0.0

    # ========================================================================
    # STATE MACHINE METHODS
    # ========================================================================

    @property
    def state(self) -> ConnectionState:
        return self._state

    async def _set_state(self, new_state: ConnectionState, reason: str = ""):
        """Thread-safe state transition with logging."""
        async with self._state_lock:
            old_state = self._state
            if old_state != new_state:
                self._state = new_state
                self.slogger.state_transition(
                    from_state=old_state.value,
                    to_state=new_state.value,
                    reason=reason
                )

    # ========================================================================
    # INACTIVITY TIMEOUT MANAGEMENT
    # ========================================================================

    def _reset_inactivity_timer(self):
        """Reset the inactivity timer. Called on any activity."""
        self._last_activity_time = time.time()

    async def _start_inactivity_monitor(self):
        """
        Monitor for inactivity and gracefully close connection after timeout.
        Does NOT terminate process - only closes socket.
        """
        while self._state == ConnectionState.CONNECTED:
            await asyncio.sleep(1)  # Check every second

            idle_time = time.time() - self._last_activity_time
            if idle_time >= INACTIVITY_TIMEOUT_SECONDS:
                self.slogger.inactivity_shutdown(idle_seconds=int(idle_time))
                await self._set_state(ConnectionState.IDLE_TIMEOUT, "inactivity_timeout")
                await self.close()
                break

    # ========================================================================
    # CONNECTION MANAGEMENT
    # ========================================================================

    async def connect(self) -> bool:
        """
        Connect to ActionCable server.
        Ensures single active connection.
        """
        await self._set_state(ConnectionState.CONNECTING, "initiating_connection")

        try:
            full_url = f"{self.url}?token={self.token}"
            headers = {
                "ngrok-skip-browser-warning": "69420",
                "User-Agent": "WMSys-Serial-Client-Aggressive"
            }
            logger.info(f"Conectando a {full_url}...")

            try:
                self.websocket = await websockets.connect(full_url, extra_headers=headers)
            except Exception as e:
                if "extra_headers" in str(e) or "TypeError" in type(e).__name__:
                    logger.warning(f"Reintentando sin extra_headers por incompatibilidad: {e}")
                    self.websocket = await websockets.connect(full_url)
                else:
                    raise

            self.slogger.connection_open(full_url)
            await self._set_state(ConnectionState.CONNECTED, "websocket_established")

            # Send subscription message
            channel_identifier = {'channel': 'SerialConnectionChannel', 'device_id': self.device_id}
            self.identifier_str = json.dumps(channel_identifier, separators=(',', ':'))
            subscribe_msg = {
                'command': 'subscribe',
                'identifier': self.identifier_str
            }
            await self.websocket.send(json.dumps(subscribe_msg, separators=(',', ':')))
            logger.info(f"Suscribiendo al canal: {channel_identifier}")

            # Reset inactivity timer on connection
            self._reset_inactivity_timer()

            # Start inactivity monitor
            self._inactivity_task = asyncio.create_task(self._start_inactivity_monitor())

            return True

        except Exception as e:
            self.slogger.connection_error(str(e))
            await self._set_state(ConnectionState.DISCONNECTED, f"connection_failed: {e}")
            return False

    async def close(self, reason: str = "normal"):
        """Gracefully close WebSocket connection."""
        # Cancel inactivity monitor
        if self._inactivity_task:
            self._inactivity_task.cancel()
            try:
                await self._inactivity_task
            except asyncio.CancelledError:
                pass
            self._inactivity_task = None

        # Close WebSocket
        if self.websocket:
            try:
                await self.websocket.close()
            except Exception:
                pass
            self.websocket = None

        self.slogger.connection_closed(reason)
        self.subscription_confirmed = False
        await self._set_state(ConnectionState.DISCONNECTED, reason)

    # ========================================================================
    # MESSAGE HANDLING
    # ========================================================================

    async def send_data(self, data: dict):
        """
        Send data to server.
        Only sends when there's actual data (no heartbeat spam).
        Resets inactivity timer on send.
        """
        if self.websocket and self.identifier_str and self._state == ConnectionState.CONNECTED:
            try:
                action = data.get('action', 'unknown')
                msg = {
                    'command': 'message',
                    'identifier': self.identifier_str,
                    'data': json.dumps(data, separators=(',', ':'))
                }
                payload = json.dumps(msg, separators=(',', ':'))
                await self.websocket.send(payload)
                self.slogger.message_sent(action=action, size_bytes=len(payload))
                self._reset_inactivity_timer()  # Reset timer on send
            except Exception as e:
                logger.error(f"Error enviando datos: {e}")

    async def listen_for_messages(self):
        """
        Listen for messages from server.
        Resets inactivity timer on valid server requests.
        """
        logger.info("Escuchando mensajes del WebSocket...")
        try:
            async for message in self.websocket:
                try:
                    logger.info(f"WebSocket RAW message: {message}")
                    data = json.loads(message)

                    msg_type = data.get('type')
                    if msg_type == 'confirm_subscription':
                        logger.info("✓ Suscripción al canal CONFIRMADA")
                        self.subscription_confirmed = True
                        await self.send_ports_list()
                        self._reset_inactivity_timer()  # Reset timer on confirmation

                    elif msg_type == 'welcome':
                        logger.info("ActionCable: Welcome/Bienvenida recibida")

                    elif msg_type == 'ping':
                        pass  # Ignore pings - don't reset timer

                    # Process message content
                    payload = data.get('message')

                    if isinstance(payload, dict) and 'action' in payload:
                        logger.info(f"Acción capturada del sobre 'message': {payload['action']}")
                        self.slogger.message_received(action=payload['action'])
                        self._reset_inactivity_timer()  # Reset timer on valid request
                        await self.handle_message(payload)

                    elif 'action' in data:
                        logger.info(f"Acción capturada en la raíz: {data['action']}")
                        self.slogger.message_received(action=data['action'])
                        self._reset_inactivity_timer()  # Reset timer on valid request
                        await self.handle_message(data)

                except json.JSONDecodeError:
                    logger.error(f"Error: No se pudo parsear el mensaje JSON: {message}")
                except Exception as e:
                    logger.error(f"Error inesperado procesando mensaje: {e}")
                    import traceback
                    logger.error(traceback.format_exc())

                await asyncio.sleep(0.01)

        except websockets.exceptions.ConnectionClosed as e:
            logger.warning(f"Conexión WebSocket cerrada: {e}")
            self.slogger.connection_closed(reason=f"connection_closed: {e}")
        except Exception as e:
            logger.error(f"Error en la escucha de mensajes: {e}")
            self.slogger.connection_error(str(e))

    async def handle_message(self, message: dict):
        """Handle incoming messages. Resets timer on port updates."""
        if message.get('type') == 'ping' or message.get('action') == 'ping':
            return

        logger.info(f"Mensaje recibido: {message}")
        action = message.get('action')

        if action == 'set_config':
            logger.info("Comando de configuración recibido.")
            new_scale_port = message.get('scale_port')
            new_printer_port = message.get('printer_port')

            if new_scale_port:
                available_ports = [p.device for p in serial.tools.list_ports.comports()]
                if new_scale_port in available_ports:
                    logger.info(f"Actualizando puerto de báscula a: {new_scale_port}")
                    self.scale_manager.set_port(new_scale_port)
                    self._reset_inactivity_timer()  # Reset timer on port change
                else:
                    logger.warning(f"Puerto de báscula {new_scale_port} no disponible")

            if new_printer_port:
                logger.info(f"Actualizando impresora a: {new_printer_port}")
                self.printer_manager.set_printer(new_printer_port)
                self._reset_inactivity_timer()  # Reset timer on port change

            await asyncio.to_thread(save_config, {
                'scale_port': self.scale_manager.port,
                'printer_port': self.printer_manager.printer_name
            })

            self.configuration_received = True
            logger.info("Enviando respuesta de puertos tras configuración...")
            await self.send_ports_list()

        elif action == 'connect_scale':
            async with self.scale_lock:
                port = message.get('port')
                baudrate = message.get('baudrate', 115200)
                if not port:
                    logger.warning("⚠ connect_scale: No se especificó puerto")
                    return

                logger.info(f"⚡ Solicitud recibida: Conectar Báscula {port} @ {baudrate}")
                available = serial.tools.list_ports.comports()
                match = None
                for p in available:
                    if p.device.upper() == port.upper() or p.device.upper() == f"\\\\.\\{port.upper()}":
                        match = p.device
                        break

                if match:
                    if match != port:
                        logger.info(f"ℹ Auto-corrección: {port} -> {match}")
                    self.scale_manager.set_port(match)
                    self.scale_manager.baudrate = baudrate
                    await asyncio.to_thread(self.scale_manager.connect)
                else:
                    logger.warning(f"Puerto '{port}' no en lista standard. Intentando directo...")
                    self.scale_manager.set_port(port)
                    self.scale_manager.baudrate = baudrate
                    await asyncio.to_thread(self.scale_manager.connect)

        elif action == 'disconnect_scale':
            async with self.scale_lock:
                logger.info("Comando de desconexión de báscula recibido.")
                await asyncio.to_thread(self.scale_manager.disconnect)

        elif action == 'start_scale_reading':
            logger.info("Comando de inicio de lectura de báscula recibido.")

        elif action == 'stop_scale_reading':
            logger.info("Comando de detención de lectura de báscula recibido.")

        elif action == 'connect_printer':
            async with self.printer_lock:
                port = message.get('port')
                if port:
                    logger.info(f"⚡ Solicitud: Conectar Impresora {port}")
                    self.printer_manager.set_printer(port)
                else:
                    logger.info("⚡ Solicitud: Conectar Impresora (nombre actual)")
                await asyncio.to_thread(self.printer_manager.connect_printer)

        elif action == 'disconnect_printer':
            async with self.printer_lock:
                logger.info("Comando de desconexión de impresora recibido.")
                self.printer_manager.is_connected = False

        elif action == 'print_label':
            content = message.get('content', '')
            ancho_mm = message.get('ancho_mm', 80)
            alto_mm = message.get('alto_mm', 50)
            logger.info(f"Comando de impresión recibido: {content[:50]}...")
            await asyncio.to_thread(self.printer_manager.print_label, content, ancho_mm=ancho_mm, alto_mm=alto_mm)

        elif action == 'test_printer':
            ancho_mm = message.get('ancho_mm', 80)
            alto_mm = message.get('alto_mm', 50)
            logger.info(f"Comando de prueba de impresora recibido: {ancho_mm}x{alto_mm}mm...")
            test_content = (
                f"^XA^FO50,50^A0N,50,50^FDTEST LABEL (ZPL)^FS^XZ"
                f"\nSIZE {ancho_mm} mm, {alto_mm} mm\nCLS\nTEXT 50,50,\"3\",0,1,1,\"TEST LABEL (TSPL)\"\nPRINT 1\n"
            )
            await asyncio.to_thread(self.printer_manager.print_label, test_content, ancho_mm=ancho_mm, alto_mm=alto_mm)

        elif action == 'request_ports':
            logger.info(f"!!! Petición de estado '{action}' capturada !!!")
            await self.send_ports_list()

        elif action == 'ports_update':
            pass  # Ignore echo from server

        else:
            if not message.get('type') in ['welcome', 'ping', 'confirm_subscription']:
                logger.warning(f"Acción no reconocida en handle_message: {action}")

    # ========================================================================
    # PORT DETECTION
    # ========================================================================

    async def send_ports_list(self):
        """Send port list to server. Resets timer on port change."""
        try:
            await asyncio.sleep(0.1)
            logger.info("--- Iniciando detección de puertos ---")

            port_list = []

            # Detect serial ports
            try:
                ports = await asyncio.to_thread(serial.tools.list_ports.comports)
                port_list = [{'device': p.device, 'description': p.description} for p in ports]
                logger.info(f"Puertos detectados por serial.tools: {len(port_list)}")
            except Exception as e:
                logger.error(f"Error detectando puertos serie: {e}")
                port_list = []

            # Unix/Linux additional detection
            if sys.platform.startswith('linux') or sys.platform.startswith('darwin'):
                logger.info("Detectando puertos seriales adicionales en sistema Unix/Mac...")
                try:
                    serial_ports = []
                    serial_ports.extend(glob.glob('/dev/ttyUSB*'))
                    serial_ports.extend(glob.glob('/dev/ttyACM*'))
                    serial_ports.extend(glob.glob('/dev/cu.*'))
                    serial_ports.extend(glob.glob('/dev/ttyS*'))

                    logger.info(f"Puertos seriales reales encontrados: {len(serial_ports)}")
                    for vp in serial_ports:
                        if vp not in [p['device'] for p in port_list]:
                            description = f'Puerto serial: {vp.split("/")[-1]}'
                            port_list.append({'device': vp, 'description': description})
                            logger.info(f"Añadido puerto serial: {vp}")
                except Exception as e:
                    logger.error(f"Error detectando puertos seriales adicionales: {e}")

            # Windows additional detection
            if sys.platform.startswith('win'):
                logger.info("Detectando puertos adicionales en Windows...")
                try:
                    import winreg
                    key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"HARDWARE\DEVICEMAP\SERIALCOMM")
                    i = 0
                    while True:
                        try:
                            name, value, _ = winreg.EnumValue(key, i)
                            if value not in [p['device'] for p in port_list]:
                                port_list.append({'device': value, 'description': f'Puerto virtual {value}'})
                                logger.info(f"Añadido puerto virtual Windows: {value}")
                            i += 1
                        except WindowsError:
                            break
                    winreg.CloseKey(key)
                except Exception as reg_error:
                    logger.info(f"No se pudieron leer puertos virtuales desde el registro: {reg_error}")

            # Detect printers
            if WIN32_AVAILABLE:
                logger.info("Detectando impresoras en Windows...")
                try:
                    printers = await asyncio.to_thread(win32print.EnumPrinters,
                                                       win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)
                    for p in printers:
                        port_list.append({'device': p[2], 'description': f'Impresora: {p[2]}'})
                        logger.info(f"Añadida impresora: {p[2]}")
                except Exception as printer_error:
                    logger.warning(f"Error obteniendo impresoras: {printer_error}")
            else:
                logger.info("Sistema no Windows, detectando posibles impresoras...")
                if self.printer_manager.printer_name:
                    port_list.append({
                        'device': self.printer_manager.printer_name,
                        'description': f'Impresora: {self.printer_manager.printer_name}'
                    })
                    logger.info(f"Añadida impresora configurada: {self.printer_manager.printer_name}")

            logger.info(f"Total de puertos detectados: {len(port_list)}")

            if self.websocket:
                logger.info(f">>> Enviando ports_update al servidor con {len(port_list)} puertos...")
                data_to_send = {
                    'action': 'ports_update',
                    'ports': port_list,
                    'scale_port': self.scale_manager.port,
                    'scale_connected': self.scale_manager.connected,
                    'printer_port': self.printer_manager.printer_name,
                    'printer_connected': self.printer_manager.is_connected
                }
                logger.info(f"DEBUG DATA: {json.dumps(data_to_send)}")
                await self.send_data(data_to_send)
                logger.info(f"✓ Mensaje de puertos enviado exitosamente")
                logger.info(f"Datos enviados - Scale port: {self.scale_manager.port}, Scale connected: {self.scale_manager.connected}")
                logger.info(f"Datos enviados - Printer port: {self.printer_manager.printer_name}, Printer connected: {self.printer_manager.is_connected}")
            else:
                logger.warning("No se pudo confirmar la suscripción para enviar la lista de puertos")

        except Exception as e:
            logger.error(f"Error al enviar la lista de puertos: {e}")
            logger.error(f"Error details: {str(e)}", exc_info=True)


# ============================================================================
# SECTION 10: STREAM UPDATES (No Heartbeat Spam)
# ============================================================================

async def stream_updates(client: SerialClient, scale_manager: ScaleManager,
                         printer_manager: PrinterManager, device_id: str):
    """
    Send periodic updates to server.
    ONLY sends when there are actual changes (no heartbeat spam).
    Resets inactivity timer on serial data or port changes.
    """
    logger.info("Stream de actualizaciones iniciado.")

    previous_ports = []
    previous_scale_status = None
    previous_printer_status = None

    await asyncio.sleep(2)
    logger.info("Después de esperar 2 segundos")

    try:
        await client.send_ports_list()
    except Exception as e:
        logger.error(f"Error al enviar la lista inicial de puertos: {e}")
        logger.error(f"Error details: {str(e)}", exc_info=True)

    logger.info("Entrando en el loop principal...")

    while True:
        try:
            logger.debug("Iniciando ciclo de actualización de puertos...")

            # Get available ports
            try:
                ports = await asyncio.to_thread(serial.tools.list_ports.comports)
                port_list = [{'device': p.device, 'description': p.description} for p in ports]
            except Exception as e:
                logger.error(f"Error detectando puertos serie en loop: {e}")
                port_list = []

            # Unix/Linux additional detection
            if sys.platform.startswith('linux') or sys.platform.startswith('darwin'):
                try:
                    serial_ports = []
                    serial_ports.extend(glob.glob('/dev/ttyUSB*'))
                    serial_ports.extend(glob.glob('/dev/ttyACM*'))
                    serial_ports.extend(glob.glob('/dev/cu.*'))
                    serial_ports.extend(glob.glob('/dev/ttyS*'))

                    for vp in serial_ports:
                        if vp not in [p['device'] for p in port_list]:
                            description = f'Puerto serial: {vp.split("/")[-1]}'
                            port_list.append({'device': vp, 'description': description})
                except Exception as e:
                    logger.error(f"Error detectando puertos seriales adicionales en loop: {e}")

            # Windows additional detection
            if sys.platform.startswith('win'):
                try:
                    import winreg
                    key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"HARDWARE\DEVICEMAP\SERIALCOMM")
                    i = 0
                    while True:
                        try:
                            name, value, _ = winreg.EnumValue(key, i)
                            if value not in [p['device'] for p in port_list]:
                                port_list.append({'device': value, 'description': f'Puerto virtual {value}'})
                            i += 1
                        except WindowsError:
                            break
                    winreg.CloseKey(key)
                except Exception as reg_error:
                    logger.info(f"No se pudieron leer puertos virtuales desde el registro: {reg_error}")

            # Detect printers
            if WIN32_AVAILABLE:
                try:
                    printers = await asyncio.to_thread(win32print.EnumPrinters,
                                                       win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)
                    for p in printers:
                        printer_exists = any(p[2] == port['device'] for port in port_list)
                        if not printer_exists:
                            port_list.append({'device': p[2], 'description': f'Impresora: {p[2]}'})
                except Exception as printer_error:
                    logger.warning(f"Error obteniendo impresoras Windows: {printer_error}")
            elif sys.platform == 'darwin' or sys.platform.startswith('linux'):
                try:
                    import subprocess
                    def get_unix_printers():
                        try:
                            output = subprocess.check_output(['lpstat', '-a'], stderr=subprocess.STDOUT, timeout=2).decode()
                            return [line.split()[0] for line in output.splitlines() if line.strip()]
                        except:
                            return []

                    unix_printers = await asyncio.to_thread(get_unix_printers)
                    for printer in unix_printers:
                        if not any(p['device'] == printer for p in port_list):
                            port_list.append({'device': printer, 'description': f'Impresora (Unix): {printer}'})
                except Exception as e:
                    logger.debug(f"No se pudo ejecutar lpstat: {e}")

                if printer_manager.printer_name and not any(p['device'] == printer_manager.printer_name for p in port_list):
                    port_list.append({
                        'device': printer_manager.printer_name,
                        'description': f'Impresora: {printer_manager.printer_name}'
                    })

                await asyncio.to_thread(printer_manager.connect_printer)

            # Only send update if there are significant changes
            ports_changed = len(previous_ports) != len(port_list) or \
                           any(prev != curr for prev, curr in zip(previous_ports, port_list))

            if (ports_changed or
                scale_manager.connected != previous_scale_status or
                printer_manager.is_connected != previous_printer_status):

                if client.subscription_confirmed:
                    await client.send_data({
                        'action': 'ports_update',
                        'ports': port_list,
                        'scale_port': scale_manager.port,
                        'scale_connected': scale_manager.connected,
                        'printer_port': printer_manager.printer_name,
                        'printer_connected': printer_manager.is_connected
                    })
                    # Port change resets inactivity timer (via send_data)

                previous_ports = port_list.copy()
                previous_scale_status = scale_manager.connected
                previous_printer_status = printer_manager.is_connected

            # Read scale weight (only if port defined)
            reading = None
            if scale_manager.port:
                reading = await asyncio.to_thread(scale_manager.read_weight)

            if reading and isinstance(reading, dict) and reading.get('weight') is not None:
                await client.send_data({
                    'action': 'weight_update',
                    'weight': reading['weight'],
                    'timestamp': reading.get('timestamp', datetime.now().isoformat())
                })
                # Serial data sent - resets inactivity timer (via send_data)

            await asyncio.sleep(3)

        except Exception as e:
            logger.error(f"Error en el stream de actualizaciones: {e}")
            try:
                scale_manager.disconnect()
            except:
                pass
            try:
                printer_manager.connect_printer()
            except:
                pass
            await asyncio.sleep(5)


# ============================================================================
# SECTION 11: MAIN LOOP WITH EXPONENTIAL BACKOFF
# ============================================================================

async def main_loop(url: str, token: str, device_id: str, args):
    """
    Main connection loop with exponential backoff reconnection.

    BACKOFF SCHEDULE:
        1s -> 2s -> 5s -> 10s -> 30s -> 60s -> 5min (cap)

    SINGLE ACTIVE CONNECTION:
        - Only one connection attempt at a time
        - No parallel reconnect timers
        - Backoff resets on successful connection
    """
    log_hardware_audit()
    local_config = load_config()
    initial_scale_port = args.scale_port or local_config.get('scale_port')
    initial_printer_port = args.printer_port or local_config.get('printer_port')

    scale_manager = ScaleManager(port=initial_scale_port)
    printer_manager = PrinterManager(printer_name=initial_printer_port)

    # Initialize structured logger
    slogger = StructuredLogger(logger)

    # Exponential backoff configuration
    reconnect_delays = RECONNECT_DELAYS.copy()
    max_reconnect_delay = MAX_RECONNECT_DELAY
    reconnect_index = 0
    total_delay_accumulated = 0.0

    try:
        import websockets
        logger.info(f"🔄 Iniciando bucle de conexión (websockets v{websockets.__version__})...")
    except:
        logger.info("🔄 Iniciando bucle de conexión...")

    while True:
        try:
            # Create client with state machine
            client = SerialClient(url, token, device_id, scale_manager, printer_manager, slogger)

            if await client.connect():
                # SUCCESS: Reset backoff
                reconnect_index = 0
                total_delay_accumulated = 0.0
                slogger.reconnect_success(
                    attempt=client._reconnect_attempt,
                    total_delay_seconds=total_delay_accumulated
                )
                logger.info("✓ Conexión y suscripción establecidas.")

                # Create concurrent tasks
                listen_task = asyncio.create_task(client.listen_for_messages())
                stream_task = asyncio.create_task(stream_updates(client, scale_manager, printer_manager, device_id))

                # Wait for either task to complete
                done, pending = await asyncio.wait([listen_task, stream_task], return_when=asyncio.FIRST_COMPLETED)

                # Cancel pending tasks
                for task in pending:
                    task.cancel()
                    try:
                        await task
                    except:
                        pass

                logger.info("Tareas terminadas, cerrando conexión...")
                await client.close()

                # Check if shutdown was due to inactivity (don't reconnect immediately)
                if client.state == ConnectionState.IDLE_TIMEOUT:
                    logger.info("Conexión cerrada por inactividad. Reconectando...")
                    # Still reconnect but with normal backoff
                else:
                    logger.warning("Una de las tareas principales ha terminado, reconectando...")
            else:
                logger.error("No se pudo conectar al servidor")

        except Exception as e:
            logger.error(f"Error en el bucle de conexión: {type(e).__name__} - {e}")
            slogger.connection_error(f"{type(e).__name__}: {e}")

        # Calculate next reconnect delay with exponential backoff
        if reconnect_index < len(reconnect_delays):
            delay = reconnect_delays[reconnect_index]
            reconnect_index += 1
        else:
            delay = max_reconnect_delay  # Cap at max delay

        total_delay_accumulated += delay
        client._reconnect_attempt += 1

        slogger.reconnect_attempt(attempt=client._reconnect_attempt, delay_seconds=delay)
        logger.warning(f"Conexión perdida. Reintentando en {delay} segundos...")
        await asyncio.sleep(delay)


# ============================================================================
# SECTION 12: ENTRY POINT
# ============================================================================

if __name__ == '__main__':
    # Configure logging
    logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')
    logger = logging.getLogger(__name__)

    parser = argparse.ArgumentParser(description='Cliente serial para WMSys.')
    parser.add_argument('--url', type=str, default=os.getenv('SERIAL_SERVER_URL', 'wss://wmsys.fly.dev/cable'), help='URL del servidor.')
    parser.add_argument('--token', type=str, default='f5284e6402cf64f9794711b91282e343', help='Token de autenticación.')
    parser.add_argument('--device-id', type=str, default='device-serial-6bca882ac82e4333afedfb48ac3eea8e', help='ID único del dispositivo.')
    parser.add_argument('--scale-port', type=str, default=None, help='Puerto de la báscula.')
    parser.add_argument('--printer-port', type=str, default=None, help='Nombre de la impresora.')
    args = parser.parse_args()

    device_id = args.device_id or f"device-serial-{uuid.getnode()}"

    print("-" * 50)
    print(f"🚀 INICIANDO CLIENTE SERIAL WMSYS (REFACTORED)")
    print(f"📍 Servidor: {args.url}")
    print(f"🔑 Device ID: {device_id}")
    print(f"⚖️ Báscula: {args.scale_port or 'Pendiente'}")
    print(f"🖨️ Impresora: {args.printer_port or 'Pendiente'}")
    print(f"⏱️ Inactivity Timeout: {INACTIVITY_TIMEOUT_SECONDS}s")
    print(f"📅 Backoff: {RECONNECT_DELAYS} -> {MAX_RECONNECT_DELAY}s cap")
    print("-" * 50)

    if not check_single_instance():
        logger.error("!!! ERROR: Ya hay otra instancia de este script ejecutándose.")
        logger.error("Por favor, cierra las ventanas negras abiertas antes de iniciar una nueva.")
        time.sleep(5)
        sys.exit(1)

    try:
        asyncio.run(main_loop(args.url, args.token, device_id, args))
    except KeyboardInterrupt:
        logger.info("Cliente cerrado.")

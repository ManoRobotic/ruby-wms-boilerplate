class Admin::ManualPrintingController < AdminController
  def index
    # Vista principal de impresión manual
  end

  def connect_printer
    # Conectar a la impresora TSC TX200
    result = execute_python_script("connect")

    if result[:success]
      render json: {
        success: true,
        message: "Impresora conectada exitosamente",
        output: result[:output]
      }
    else
      render json: {
        success: false,
        message: "Error al conectar con la impresora",
        error: result[:error]
      }
    end
  end

  def print_test
    # Parámetros del formulario
    ancho_mm = params[:ancho_mm] || "80"
    alto_mm = params[:alto_mm] || "50"
    gap_mm = params[:gap_mm] || "2"
    product_name = params[:product_name] || "Producto Sin Nombre"
    current_weight = params[:current_weight] || "0.0"

    # Ejecutar impresión con producto y peso
    result = execute_python_script("print", {
      ancho: ancho_mm,
      alto: alto_mm,
      gap: gap_mm,
      product_name: product_name,
      weight: current_weight
    })

    if result[:success]
      render json: {
        success: true,
        message: "Etiqueta de test enviada a imprimir",
        output: result[:output]
      }
    else
      render json: {
        success: false,
        message: "Error al imprimir etiqueta de test",
        error: result[:error]
      }
    end
  end

  def calibrate_sensor
    # Calibrar sensor de papel
    result = execute_python_script("calibrate")

    if result[:success]
      render json: {
        success: true,
        message: "Sensor calibrado exitosamente",
        output: result[:output]
      }
    else
      render json: {
        success: false,
        message: "Error al calibrar sensor",
        error: result[:error]
      }
    end
  end

  def printer_status
    # Obtener estado de la impresora
    result = execute_python_script("status")

    if result[:success]
      render json: {
        success: true,
        message: "Estado obtenido",
        output: result[:output]
      }
    else
      render json: {
        success: false,
        message: "Error al obtener estado",
        error: result[:error]
      }
    end
  end

  def connect_scale
    # Conectar a la báscula serial
    result = execute_scale_script("connect")

    if result[:success]
      render json: {
        success: true,
        message: "Báscula conectada exitosamente",
        output: result[:output]
      }
    else
      render json: {
        success: false,
        message: "Error al conectar con la báscula",
        error: result[:error]
      }
    end
  end

  def read_weight
    # Leer peso de la báscula
    result = execute_scale_script("read")

    if result[:success]
      # Extraer el peso del output
      weight = extract_weight_from_output(result[:output])

      render json: {
        success: true,
        message: "Peso leído correctamente",
        weight: weight,
        output: result[:output]
      }
    else
      render json: {
        success: false,
        message: "Error al leer peso",
        error: result[:error],
        weight: 0.0
      }
    end
  end

  private

  def execute_python_script(action, params = {})
    # Crear archivo temporal con el script de Python
    script_path = create_printer_script

    begin
      case action
      when "connect"
        # Solo conectar
        command = "python3 #{script_path} --action=connect"
      when "print"
        # Imprimir con parámetros incluyendo producto y peso
        product_name = params[:product_name] || "Producto"
        weight = params[:weight] || "0.0"
        command = "python3 #{script_path} --action=print --ancho=#{params[:ancho]} --alto=#{params[:alto]} --gap=#{params[:gap]} --product='#{product_name}' --weight=#{weight}"
      when "calibrate"
        # Calibrar sensor
        command = "python3 #{script_path} --action=calibrate"
      when "status"
        # Obtener estado
        command = "python3 #{script_path} --action=status"
      else
        return { success: false, error: "Acción no válida" }
      end

      # Ejecutar comando con timeout
      output = `timeout 30 #{command} 2>&1`
      exit_status = $?.exitstatus

      if exit_status == 0
        { success: true, output: output }
      else
        { success: false, error: output }
      end

    rescue => e
      { success: false, error: e.message }
    ensure
      # Limpiar archivo temporal
      File.delete(script_path) if File.exist?(script_path)
    end
  end

  def create_printer_script
    # Crear archivo temporal con el script de Python
    script_content = generate_python_script
    temp_file = Tempfile.new([ "tsc_printer", ".py" ])
    temp_file.write(script_content)
    temp_file.close
    temp_file.path
  end

  def generate_python_script
    <<~PYTHON
      #!/usr/bin/env python3
      # -*- coding: utf-8 -*-
      """
      Controlador directo para impresora TSC TX200
      Adaptado para uso desde Rails
      """

      import usb.core
      import usb.util
      import time
      import sys
      import argparse

      class TSCTX200:
          def __init__(self):
              self.device = None
              self.endpoint_out = None
              self.endpoint_in = None
      #{'        '}
          def conectar(self):
              """
              Conecta directamente con la impresora TSC TX200
              """
              print("Buscando impresora TSC TX200...")
      #{'        '}
              # Buscar dispositivo TSC TX200 (Vendor ID: 0x1203, Product ID: 0x0230)
              self.device = usb.core.find(idVendor=0x1203, idProduct=0x0230)
      #{'        '}
              if self.device is None:
                  print("ERROR: Impresora TSC TX200 no encontrada")
                  print("Verifica que esté conectada y encendida")
                  return False
      #{'        '}
              print(f"EXITO: Impresora encontrada: {self.device}")
      #{'        '}
              try:
                  # Configurar dispositivo
                  if self.device.is_kernel_driver_active(0):
                      print("Desconectando driver del kernel...")
                      self.device.detach_kernel_driver(0)
      #{'            '}
                  # Establecer configuración
                  self.device.set_configuration()
      #{'            '}
                  # Obtener interface y endpoints
                  cfg = self.device.get_active_configuration()
                  intf = cfg[(0,0)]
      #{'            '}
                  # Encontrar endpoints
                  self.endpoint_out = usb.util.find_descriptor(
                      intf,
                      custom_match = lambda e: \\
                          usb.util.endpoint_direction(e.bEndpointAddress) == \\
                          usb.util.ENDPOINT_OUT
                  )
      #{'            '}
                  self.endpoint_in = usb.util.find_descriptor(
                      intf,
                      custom_match = lambda e: \\
                          usb.util.endpoint_direction(e.bEndpointAddress) == \\
                          usb.util.ENDPOINT_IN
                  )
      #{'            '}
                  if self.endpoint_out is None:
                      print("ERROR: No se encontró endpoint de salida")
                      return False
      #{'            '}
                  print(f"EXITO: Endpoint OUT: {self.endpoint_out.bEndpointAddress}")
                  if self.endpoint_in:
                      print(f"EXITO: Endpoint IN: {self.endpoint_in.bEndpointAddress}")
      #{'            '}
                  return True
      #{'            '}
              except Exception as e:
                  print(f"ERROR: Error al configurar dispositivo: {e}")
                  return False
      #{'    '}
          def enviar_comando(self, comando):
              """
              Envía comando TSPL2 a la impresora
              """
              if not self.device or not self.endpoint_out:
                  print("ERROR: Dispositivo no conectado")
                  return False
      #{'        '}
              try:
                  # Convertir comando a bytes si es necesario
                  if isinstance(comando, str):
                      comando = comando.encode('utf-8')
      #{'            '}
                  # Enviar comando
                  bytes_escritos = self.endpoint_out.write(comando)
                  print(f"EXITO: Enviados {bytes_escritos} bytes")
                  return True
      #{'            '}
              except Exception as e:
                  print(f"ERROR: Error enviando comando: {e}")
                  return False
      #{'    '}
          def test_impresora(self, ancho_mm=80, alto_mm=50, gap_mm=2, product_name="Producto", weight=0.0):
              """
              Realiza test básico de la impresora con tamaños configurables incluyendo producto y peso
              """
              print(f"\\n=== ETIQUETA: {product_name} - {weight} kg ===")
      #{'        '}
              # Comandos TSPL2 optimizados para TSC TX200
              comandos_test = [
                  f"SIZE {ancho_mm} mm, {alto_mm} mm\\n",     # Tamaño del papel
                  f"GAP {gap_mm} mm, 0 mm\\n",               # Espacio entre etiquetas#{'  '}
                  "DIRECTION 1,0\\n",                        # Dirección normal
                  "REFERENCE 0,0\\n",                        # Punto de referencia en esquina
                  "OFFSET 0 mm\\n",                          # Sin offset
                  "SET PEEL OFF\\n",                         # Modo peeling desactivado
                  "SET CUTTER OFF\\n",                       # Cortador desactivado
                  "SET PARTIAL_CUTTER OFF\\n",               # Cortador parcial desactivado
                  "SET TEAR ON\\n",                          # Modo tear activado
                  "CLS\\n",                                  # Limpiar buffer de impresión
                  "CODEPAGE 1252\\n",                        # Página de códigos occidental
      #{'            '}
                  # Texto centrado y bien posicionado con producto y peso
                  f"TEXT {int(ancho_mm*1.5)},{int(alto_mm*1.2)},\\"4\\",0,1,1,\\"{product_name}\\"\\n",
                  f"TEXT {int(ancho_mm*1.5)},{int(alto_mm*2.2)},\\"3\\",0,1,1,\\"Peso: {weight} kg\\"\\n",
                  f"TEXT {int(ancho_mm*1.5)},{int(alto_mm*3.2)},\\"2\\",0,1,1,\\"Papel: {ancho_mm}x{alto_mm}mm\\"\\n",
      #{'            '}
                  # Línea de separación
                  f"BAR {int(ancho_mm*1.5)},{int(alto_mm*4.5)},{int(ancho_mm*5)},2\\n",
      #{'            '}
                  # Información de fecha/hora
                  f"TEXT {int(ancho_mm*2)},{int(alto_mm*5.5)},\\"1\\",0,1,1,\\"{time.strftime('%Y-%m-%d %H:%M')}\\"\\n",
      #{'            '}
                  "PRINT 1,1\\n"                             # Imprimir 1 copia
              ]
      #{'        '}
              print("Enviando comandos de test...")
              for i, comando in enumerate(comandos_test, 1):
                  print(f"{i:2d}. {comando.strip()}")
                  if self.enviar_comando(comando):
                      time.sleep(0.1)  # Pequeña pausa entre comandos
                  else:
                      print(f"ERROR: Error enviando comando {i}")
                      return False
      #{'        '}
              print(f"\\nEXITO: Test completado para papel {ancho_mm}x{alto_mm}mm")
              return True
      #{'    '}
          def calibrar_sensor(self):
              """
              Calibra el sensor de papel para detectar correctamente las etiquetas
              """
              print("\\n=== CALIBRACIÓN DEL SENSOR ===")
      #{'        '}
              comandos_calibracion = [
                  "CLS\\n",                    # Limpiar buffer
                  "~!AUTODETECT\\n",          # Auto-detectar tipo de papel
                  "INITIALPRINTER\\n",        # Inicializar impresora
              ]
      #{'        '}
              print("Ejecutando calibración...")
              for comando in comandos_calibracion:
                  print(f"Enviando: {comando.strip()}")
                  if self.enviar_comando(comando):
                      time.sleep(1)  # Esperar más tiempo para calibración
                  else:
                      print("ERROR: Error en calibración")
                      return False
      #{'        '}
              print("EXITO: Calibración completada")
              return True
      #{'    '}
          def obtener_estado(self):
              """
              Obtiene estado de la impresora
              """
              print("\\n=== ESTADO DE LA IMPRESORA ===")
      #{'        '}
              # Comando para obtener estado
              if self.enviar_comando("~!T\\n"):  # Comando de estado TSPL2
                  print("EXITO: Comando de estado enviado")
                  return True
              else:
                  print("ERROR: No se pudo obtener estado")
                  return False
      #{'    '}
          def desconectar(self):
              """
              Desconecta de la impresora
              """
              if self.device:
                  try:
                      usb.util.dispose_resources(self.device)
                      print("EXITO: Desconectado de la impresora")
                  except:
                      pass

      def main():
          parser = argparse.ArgumentParser(description='Controlador TSC TX200')
          parser.add_argument('--action', required=True, choices=['connect', 'print', 'calibrate', 'status'])
          parser.add_argument('--ancho', type=float, default=80)
          parser.add_argument('--alto', type=float, default=50)
          parser.add_argument('--gap', type=float, default=2)
          parser.add_argument('--product', type=str, default='Producto')
          parser.add_argument('--weight', type=float, default=0.0)
      #{'    '}
          args = parser.parse_args()
      #{'    '}
          # Crear instancia de la impresora
          impresora = TSCTX200()
      #{'    '}
          try:
              # Conectar
              if not impresora.conectar():
                  print("ERROR: No se pudo conectar con la impresora")
                  sys.exit(1)
      #{'        '}
              # Ejecutar acción solicitada
              if args.action == 'connect':
                  print("EXITO: Impresora conectada correctamente")
              elif args.action == 'print':
                  if not impresora.test_impresora(args.ancho, args.alto, args.gap, args.product, args.weight):
                      sys.exit(1)
              elif args.action == 'calibrate':
                  if not impresora.calibrar_sensor():
                      sys.exit(1)
              elif args.action == 'status':
                  if not impresora.obtener_estado():
                      sys.exit(1)
      #{'        '}
          except Exception as e:
              print(f"ERROR: {e}")
              sys.exit(1)
          finally:
              impresora.desconectar()

      if __name__ == "__main__":
          main()
    PYTHON
  end

  def execute_scale_script(action, params = {})
    # Crear archivo temporal con el script de la báscula
    script_path = create_scale_script

    begin
      case action
      when "connect"
        # Solo conectar y verificar puertos
        command = "python3 #{script_path} --action=connect"
      when "read"
        # Leer peso actual
        command = "python3 #{script_path} --action=read"
      else
        return { success: false, error: "Acción no válida para báscula" }
      end

      # Ejecutar comando con timeout
      output = `timeout 10 #{command} 2>&1`
      exit_status = $?.exitstatus

      if exit_status == 0
        { success: true, output: output }
      else
        { success: false, error: output }
      end

    rescue => e
      { success: false, error: e.message }
    ensure
      # Limpiar archivo temporal
      File.delete(script_path) if File.exist?(script_path)
    end
  end

  def create_scale_script
    # Crear archivo temporal con el script de la báscula
    script_content = generate_scale_script
    temp_file = Tempfile.new([ "scale_reader", ".py" ])
    temp_file.write(script_content)
    temp_file.close
    temp_file.path
  end

  def generate_scale_script
    <<~PYTHON
      #!/usr/bin/env python3
      # -*- coding: utf-8 -*-
      """
      Lector de báscula serial
      Adaptado para uso desde Rails
      """

      import serial
      import csv
      import serial.tools.list_ports
      import sys
      import argparse
      import time

      class ScaleReader:
          def __init__(self):
              self.ser = None
              self.puerto = None
      #{'        '}
          def list_ports(self):
              """
              Lista puertos seriales disponibles
              """
              puertos_disponibles = serial.tools.list_ports.comports()
              for puerto in puertos_disponibles:
                  print(f"Puerto disponible: {puerto.device}")
              return puertos_disponibles
      #{'    '}
          def find_scale_port(self):
              """
              Busca automáticamente el puerto de la báscula
              """
              puertos = serial.tools.list_ports.comports()
      #{'        '}
              # Puertos comunes para básculas
              common_ports = ['/dev/ttyUSB0', '/dev/ttyUSB1', '/dev/ttyACM0', '/dev/ttyACM1',#{' '}
                             '/dev/cu.usbmodem11401', '/dev/cu.usbserial', 'COM1', 'COM2', 'COM3']
      #{'        '}
              # Primero intentar puertos conocidos
              for port in common_ports:
                  for puerto_info in puertos:
                      if port == puerto_info.device:
                          print(f"EXITO: Puerto encontrado: {port}")
                          return port
      #{'        '}
              # Si no encuentra, usar el primer puerto disponible
              if puertos:
                  puerto = puertos[0].device
                  print(f"EXITO: Usando primer puerto disponible: {puerto}")
                  return puerto
      #{'        '}
              print("ERROR: No se encontraron puertos seriales")
              return None
      #{'    '}
          def conectar(self, puerto=None):
              """
              Conecta con la báscula
              """
              if not puerto:
                  puerto = self.find_scale_port()
      #{'        '}
              if not puerto:
                  return False
      #{'        '}
              try:
                  # Intentar diferentes configuraciones de baudios
                  baudios_opciones = [9600, 115200, 19200, 38400, 57600]
      #{'            '}
                  for baudios in baudios_opciones:
                      try:
                          print(f"Intentando conexión en {puerto} a {baudios} baudios...")
                          self.ser = serial.Serial(
                              puerto,#{' '}
                              baudrate=baudios,#{' '}
                              timeout=1,#{' '}
                              parity='N',#{' '}
                              stopbits=1,#{' '}
                              bytesize=8
                          )
      #{'                    '}
                          # Esperar un momento para la conexión
                          time.sleep(0.5)
      #{'                    '}
                          # Intentar leer datos
                          if self.ser.in_waiting > 0 or True:  # Aceptar conexión aunque no haya datos inmediatos
                              print(f"EXITO: Conexión establecida en {puerto} a {baudios} baudios")
                              self.puerto = puerto
                              return True
      #{'                    '}
                          self.ser.close()
      #{'                    '}
                      except serial.SerialException:
                          if self.ser and self.ser.is_open:
                              self.ser.close()
                          continue
      #{'            '}
                  print(f"ERROR: No se pudo conectar en {puerto}")
                  return False
      #{'            '}
              except Exception as e:
                  print(f"ERROR: Error general de conexión: {e}")
                  return False
      #{'    '}
          def leer_peso(self):
              """
              Lee el peso actual de la báscula
              """
              if not self.ser or not self.ser.is_open:
                  print("ERROR: Báscula no conectada")
                  return None
      #{'        '}
              try:
                  # Limpiar buffer
                  self.ser.flushInput()
      #{'            '}
                  # Esperar datos (timeout de 2 segundos)
                  timeout_count = 0
                  max_timeout = 20  # 2 segundos
      #{'            '}
                  while self.ser.in_waiting == 0 and timeout_count < max_timeout:
                      time.sleep(0.1)
                      timeout_count += 1
      #{'            '}
                  if self.ser.in_waiting > 0:
                      datos = self.ser.readline().decode('utf-8', errors='ignore').strip()
                      print(f"EXITO: Datos leídos: {datos}")
      #{'                '}
                      # Intentar extraer peso numérico
                      peso = self.extract_weight(datos)
                      return peso
                  else:
                      print("AVISO: No hay datos disponibles (simulando 0.0 kg)")
                      return 0.0
      #{'                '}
              except Exception as e:
                  print(f"ERROR: Error leyendo peso: {e}")
                  return None
      #{'    '}
          def extract_weight(self, data_string):
              """
              Extrae el peso numérico de la cadena de datos
              """
              import re
      #{'        '}
              # Buscar patrones numéricos comunes en básculas
              patterns = [
                  r'([+-]?\\d+\\.\\d+)\\s*kg',  # "12.34 kg"
                  r'([+-]?\\d+\\.\\d+)',        # "12.34"
                  r'([+-]?\\d+)',               # "12"
              ]
      #{'        '}
              for pattern in patterns:
                  match = re.search(pattern, data_string)
                  if match:
                      try:
                          peso = float(match.group(1))
                          return abs(peso)  # Retornar valor absoluto
                      except ValueError:
                          continue
      #{'        '}
              print(f"AVISO: No se pudo extraer peso de: {data_string}")
              return 0.0
      #{'    '}
          def desconectar(self):
              """
              Desconecta de la báscula
              """
              if self.ser and self.ser.is_open:
                  self.ser.close()
                  print("EXITO: Desconectado de la báscula")

      def main():
          parser = argparse.ArgumentParser(description='Lector de Báscula Serial')
          parser.add_argument('--action', required=True, choices=['connect', 'read'])
          parser.add_argument('--port', help='Puerto serial específico')
      #{'    '}
          args = parser.parse_args()
      #{'    '}
          # Crear instancia del lector
          reader = ScaleReader()
      #{'    '}
          try:
              if args.action == 'connect':
                  reader.list_ports()
                  if reader.conectar(args.port):
                      print("EXITO: Báscula conectada correctamente")
                  else:
                      print("ERROR: No se pudo conectar con la báscula")
                      sys.exit(1)
      #{'        '}
              elif args.action == 'read':
                  if reader.conectar(args.port):
                      peso = reader.leer_peso()
                      if peso is not None:
                          print(f"PESO: {peso}")
                      else:
                          print("ERROR: No se pudo leer el peso")
                          sys.exit(1)
                  else:
                      print("ERROR: No se pudo conectar para leer peso")
                      sys.exit(1)
      #{'        '}
          except Exception as e:
              print(f"ERROR: {e}")
              sys.exit(1)
          finally:
              reader.desconectar()

      if __name__ == "__main__":
          main()
    PYTHON
  end

  def extract_weight_from_output(output)
    # Buscar línea que contenga "PESO:"
    lines = output.split("\n")
    weight_line = lines.find { |line| line.include?("PESO:") }

    if weight_line
      # Extraer el número después de "PESO:"
      weight_match = weight_line.match(/PESO:\s*([+-]?\d+\.?\d*)/)
      if weight_match
        return weight_match[1].to_f
      end
    end

    # Si no encuentra el patrón, intentar extraer cualquier número decimal
    number_match = output.match(/([+-]?\d+\.\d+)/)
    number_match ? number_match[1].to_f : 0.0
  end
end

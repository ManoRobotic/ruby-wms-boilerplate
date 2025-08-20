require 'axlsx'

puts "Generando nuevo archivo de Excel con órdenes de producción ficticias..."

# Crear un nuevo paquete de Excel
Axlsx::Package.new do |p|
  # Crear un nuevo libro de trabajo
  p.workbook.add_worksheet(name: "ORDEN PRODUCCION") do |sheet|
    # Agregar la fila de encabezado
    headers = [
      "NO_ORDP(ORDPROC)",
      "CLAVE_COPR",
      "CVE_SUC",
      "REN_COPR(CANTIDAD)",
      "ESTATUS",
      "FECH_ORDP",
      "LOTE(ELLOS LLENAN)",
      "NO OPRO",
      "CARGA_COPR",
      "ANO",
      "MES",
      "FECHA TOTAL",
      "PESO"
    ]
    sheet.add_row headers

    # Agregar primera orden de producción ficticia
    sheet.add_row [
      "DUMMY001",
      "PRODUCTO-A",
      "WH-1",
      100,
      "pending",
      Date.today,
      "LOTE-A",
      "OP-DUMMY-001",
      1.5,
      Date.today.year,
      Date.today.month,
      Date.today,
      50.5
    ]

    # Agregar segunda orden de producción ficticia
    sheet.add_row [
      "DUMMY002",
      "PRODUCTO-B",
      "WH-2",
      250,
      "in_progress",
      Date.today,
      "LOTE-B",
      "OP-DUMMY-002",
      2.8,
      Date.today.year,
      Date.today.month,
      Date.today,
      120.2
    ]

    # Agregar tercera orden de producción ficticia
    sheet.add_row [
      "DUMMY003",
      "PRODUCTO-C",
      "WH-1",
      50,
      "completed",
      Date.today,
      "LOTE-C",
      "OP-DUMMY-003",
      0.8,
      Date.today.year,
      Date.today.month,
      Date.today,
      25.0
    ]

    # Agregar cuarta orden de producción ficticia
    sheet.add_row [
      "DUMMY004",
      "PRODUCTO-D",
      "WH-3",
      500,
      "pending",
      Date.today,
      "LOTE-D",
      "OP-DUMMY-004",
      5.0,
      Date.today.year,
      Date.today.month,
      Date.today,
      250.0
    ]

    # Agregar quinta orden de producción ficticia
    sheet.add_row [
      "DUMMY005",
      "PRODUCTO-E",
      "WH-2",
      120,
      "scheduled",
      Date.today,
      "LOTE-E",
      "OP-DUMMY-005",
      1.2,
      Date.today.year,
      Date.today.month,
      Date.today,
      60.0
    ]
  end

  # Guardar el archivo
  p.serialize("merged_new.xlsx")
end

puts "¡Archivo 'merged_new.xlsx' creado exitosamente!"
puts "Por favor, sigue estos pasos:"
puts "1. Reemplaza tu archivo 'merged.xlsx' con 'merged_new.xlsx'."
puts "2. Asegúrate de que la gema 'axlsx' esté instalada ejecutando: gem install axlsx"

# Configuración de Google Sheets OPRO

Este documento describe cómo configurar la integración con Google Sheets para sincronizar órdenes de producción (OPRO).

## 1. Configuración de Google Cloud Platform

### Crear un Proyecto
1. Ir a [Google Cloud Console](https://console.cloud.google.com/)
2. Crear un nuevo proyecto o seleccionar uno existente

### Habilitar APIs
Habilitar las siguientes APIs:
- Google Sheets API
- Google Drive API

### Crear Cuenta de Servicio
1. Ir a "IAM & Admin" > "Service Accounts"
2. Hacer clic en "Create Service Account"
3. Rellenar los datos:
   - **Nombre**: `ruby-wms-opro`
   - **Descripción**: `Service account para sincronización OPRO`
4. Dar permisos de "Editor" al proyecto
5. Crear y descargar la clave JSON

## 2. Configuración del Archivo de Credenciales

### Ubicar el archivo
Copiar el archivo JSON descargado a una de estas ubicaciones:
- `/workspaces/ruby-wms-boilerplate/config/credentials.json`
- `/workspaces/ruby-wms-boilerplate/keys/credentials.json`
- `/workspaces/ruby-wms-boilerplate/credentials.json`

### Variables de Entorno (Alternativa)
También se puede configurar usando variables de entorno:
```bash
export GOOGLE_CREDENTIALS_PATH="/path/to/credentials.json"
```

## 3. Configuración del Google Sheet

### Sheet OPRO
- **ID del Sheet**: `1RK8FZaQZjd-HPcs8ewFxj-YQUZvRB_DO68U25EZ4qDk`
- **GID de la Hoja**: `1973766435`

### Permisos
1. Abrir el Google Sheet de OPRO
2. Hacer clic en "Share"
3. Agregar el email de la cuenta de servicio con permisos de "Viewer"
   - El email estará en el archivo JSON como `client_email`

### Estructura Esperada
El sheet debe tener estas columnas (primera fila):
- `NO_OPRO`: Número de orden de producción
- `FEC_OPRO`: Fecha de la orden (YYYY-MM-DD)
- `REN_ORP`: Referencia de orden relacionada
- `STAT_OPRO`: Estatus (solo se procesan las "emitidas")
- `Clave producto`: Ejemplo: "BOPPTRANS 35 / 420"

## 4. Uso de la Funcionalidad

### Sincronización Manual
1. Ir a Admin > Órdenes de Producción
2. Hacer clic en "Sincronizar OPRO"
3. Confirmar la sincronización

### Lo que hace la sincronización
- Lee todas las filas del Google Sheet OPRO
- Filtra solo órdenes con `STAT_OPRO = "emitida"`
- Crea o actualiza órdenes de producción en el sistema
- Genera lotes automáticamente (formato: `FE-CR-DDMMAA`)
- Extrae micras y ancho del campo "Clave producto"

### Formato de Lote
- **Fuente**: Campo `FEC_OPRO` (fecha de la orden)
- **Formato**: `FE-CR-DDMMAA`
- **Ejemplo**: Para fecha `2023-04-04` → `FE-CR-040423`

### Consecutivos/Folios
- Se crean manualmente desde la vista de cada orden
- Formato: `{LOTE}-{NUMERO}` (ej: `FE-CR-040423-1`)
- Cálculos automáticos:
  - **Peso Neto**: Peso Bruto - (Peso Core / 1000)
  - **Metros**: ((Peso Neto × 1,000,000) ÷ Micras ÷ Ancho ÷ 0.92)

## 5. Estructura de Datos

### ProductionOrder (Orden Padre)
- `no_opro`: Número OPRO del sheet
- `fecha_completa`: Fecha de la orden
- `lote_referencia`: Lote generado (FE-CR-DDMMAA)
- `stat_opro`: Estatus desde el sheet
- `ren_orp`: Referencia de orden relacionada

### ProductionOrderItem (Consecutivos)
- `folio_consecutivo`: Folio único (FE-CR-DDMMAA-N)
- `peso_bruto`: Peso de la báscula (kg)
- `peso_core_gramos`: Peso del core (gramos)
- `peso_neto`: Calculado automáticamente
- `metros_lineales`: Calculado automáticamente
- `micras`: Especificación del producto
- `ancho_mm`: Ancho en milímetros
- `altura_cm`: Altura del core para cálculos

## 6. Troubleshooting

### Errores Comunes

#### "No se encontró el archivo de credenciales"
- Verificar que el archivo esté en una de las ubicaciones esperadas
- Verificar que el archivo JSON sea válido

#### "Hoja de trabajo no encontrada"
- Verificar que el GID de la hoja sea correcto
- Verificar que la cuenta de servicio tenga permisos en el sheet

#### "Acceso denegado"
- Verificar que la cuenta de servicio esté compartida en el Google Sheet
- Verificar que las APIs estén habilitadas en Google Cloud

### Logs
Los logs de sincronización se encuentran en:
```
bin/rails console
Rails.logger.info "Verificando logs de sincronización"
```
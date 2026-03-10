# Rzavala DBF Uploader

Script único para subir **órdenes de producción** y **códigos de inventario** de **Rzavala** al sistema WMS.

## Archivos Generados

Cuando se hace push a GitHub, se generan **4 executables**:

| Nombre | Propósito | Ruta de Datos |
|--------|-----------|---------------|
| `flexiempaques-serial-server-exe` | Servidor serial para Flexiempaques | - |
| `rzavala-serial-server-exe` | Servidor serial para Rzavala | - |
| `dbf-uploader-exe` | Subir órdenes de producción (Flexiempaques) | `C:\ALPHAERP\Empresas\FLEXIEMP\opro.dbf` |
| **`rzavala-dbf-uploader-exe`** | **Subir OPRO + Inventario (Rzavala)** | `C:\ALPHAERP\Empresas\RZAVALA\*.dbf` |

---

## Rzavala DBF Uploader

### Función
Un solo executable que sube:
1. **Órdenes de producción** desde `opro.dbf` + `oprod.dbf`
2. **Códigos de inventario** desde `remd.dbf`

### Rutas de Archivos (en producción)
```
C:\ALPHAERP\Empresas\RZAVALA\
├── remd.dbf        → Códigos de inventario
├── opro.dbf        → Órdenes de producción (header)
└── oprod.dbf       → Órdenes de producción (detalles)
```

### Uso
```bash
# Ejecutar el uploader (sube ambos tipos de datos)
rzavala_dbf_uploader.exe
```

### Archivos de estado
- `rzavala_opro_state.json` - Trackea el último NO_OPRO procesado
- `rzavala_inventory_state.json` - Trackea el último NO_ORDP procesado
- `rzavala_modified_state.json` - Trackea cambios en los archivos DBF
- `rzavala_dbf_uploader.log` - Log de ejecución

---

## Configuración

### Token de Rzavala
```
X-Company-Token: 74bf5e0a6ae8813dfe80593ed84a7a9c
```

### Warehouse ID para Rzavala
```
f7a1f77a-0802-49e3-871e-55bc917094f9
```

### Company Name
```
Rzavala
```

---

## Campos que Sube

### Órdenes de Producción (opro.dbf + oprod.dbf)
| Campo DBF | Campo API | Descripción |
|-----------|-----------|-------------|
| `NO_OPRO` | `no_opro` | Número de orden |
| `CVE_PROP` | `product_key` | Código de producto |
| `FEC_OPRO` | `ano` | Fecha (extrae año) |
| `STAT_OPRO` | `stat_opro` | Estado |
| `CARGA_OPRO` | `carga_copr` | Cantidad |
| `REN_OPRO` | `ren_orp` | Ren |
| `LOTE` | `lote_referencia` | Lote |
| `OBSERVA` | `notes` | Observaciones |

### Códigos de Inventario (remd.dbf)
| Campo DBF | Campo API | Descripción |
|-----------|-----------|-------------|
| `NO_ORDP` | `no_ordp` | Número de orden |
| `CVE_PROD` | `cve_prod` | Código de producto |
| `CVE_COPR` | `cve_copr` | Código de componente |
| `CAN_PROD` / `CANT_PROD` | `can_copr` | Cantidad |
| `LOTE` | `lote` | Lote |
| `FECH_ORDP` | `fech_cto` | Fecha |

---

## Características

### Procesamiento Dual
- **Primero** sube órdenes de producción
- **Después** sube códigos de inventario
- Ambos procesos son independientes

### Incremental
- Detecta automáticamente qué registros son nuevos
- Usa el número de orden (NO_OPRO / NO_ORDP) como secuencia
- Solo procesa registros mayores al último procesado

### Detección de Cambios
- Monitorea la fecha de modificación de los archivos DBF
- Si el archivo no ha cambiado, no vuelve a subir

### Reintentos
- Reintenta automáticamente hasta 3 veces en caso de error
- Backoff exponencial entre intentos

### Batch Processing
- Envía registros en lotes de 25
- Optimizado para no saturar la API

### Vinculación con Rzavala
- **Token**: `74bf5e0a6ae8813dfe80593ed84a7a9c`
- **Company Name**: `Rzavala` en el payload
- **Warehouse ID**: `f7a1f77a-0802-49e3-871e-55bc917094f9`

La API usa el token para autenticar y asignar todos los registros a la empresa **Rzavala**.

---

## Dependencias

Los executables incluyen todas las dependencias:
- `requests` - Para llamadas HTTP a la API
- `dbfread` - Para leer archivos DBF
- `pyinstaller` - Para crear el executable

---

## Troubleshooting

### Ver logs
Revisa el archivo `rzavala_dbf_uploader.log` para ver detalles de ejecución.

### Forzar re-procesamiento
Elimina los archivos de estado:
```bash
del rzavala_opro_state.json
del rzavala_inventory_state.json
del rzavala_modified_state.json
```

### Error "File not found"
Asegúrate de que los archivos DBF existan en:
```
C:\ALPHAERP\Empresas\RZAVALA\
```

### Error de conexión a API
Verifica que:
- El servidor WMS esté accesible (https://wmsys.fly.dev)
- El token de Rzavala sea correcto
- Tengas conexión a internet

### Error con archivos memo (.dbt/.fpt)
Algunos DBF requieren archivos memo adicionales. Si ves errores de memo:
1. Asegúrate de que los archivos `.dbt` o `.fpt` estén en la misma carpeta
2. El script usa `ignore_missing_memofile=False` para manejar esto

---

## Flujo de Ejecución

```
1. Inicio
   │
   ├─→ 2. Procesar Órdenes de Producción
   │      ├─→ Cargar opro.dbf + oprod.dbf
   │      ├─→ Fusionar registros por NO_OPRO
   │      ├─→ Filtrar registros nuevos (NO_OPRO > último procesado)
   │      ├─→ Enviar en batches de 25
   │      └─→ Guardar estado
   │
   ├─→ 3. Procesar Códigos de Inventario
   │      ├─→ Cargar remd.dbf
   │      ├─→ Filtrar registros nuevos (NO_ORDP > último procesado)
   │      ├─→ Enviar en batches de 25
   │      └─→ Guardar estado
   │
   └─→ 4. Fin
```

---

## Ejemplo de Log

```
2026-03-10 10:00:00 - INFO - ============================================================
2026-03-10 10:00:00 - INFO - ZAVALA DBF UPLOADER - Starting
2026-03-10 10:00:00 - INFO - Company: Rzavala
2026-03-10 10:00:00 - INFO - ============================================================
2026-03-10 10:00:01 - INFO - Fetching last NO_OPRO from API...
2026-03-10 10:00:02 - INFO - API returned last NO_OPRO: 999
2026-03-10 10:00:03 - INFO - ============================================================
2026-03-10 10:00:03 - INFO - PROCESSING ZAVALA PRODUCTION ORDERS
2026-03-10 10:00:03 - INFO - ============================================================
2026-03-10 10:00:04 - INFO - Opening DBF file: C:\ALPHAERP\Empresas\RZAVALA\opro.dbf
2026-03-10 10:00:05 - INFO - Loaded 150 records from opro.dbf
2026-03-10 10:00:06 - INFO - Found 50 new records based on NO_OPRO sequence
2026-03-10 10:00:07 - INFO - Processing batch 1 (25 records, OPROs 1000 - 1024)
2026-03-10 10:00:09 - INFO - API processed batch: 25/25 records successful
2026-03-10 10:00:10 - INFO - Processing batch 2 (25 records, OPROs 1025 - 1049)
2026-03-10 10:00:12 - INFO - API processed batch: 25/25 records successful
2026-03-10 10:00:13 - INFO - Total production orders sent: 50/50
2026-03-10 10:00:14 - INFO - ============================================================
2026-03-10 10:00:14 - INFO - PROCESSING ZAVALA INVENTORY CODES
2026-03-10 10:00:14 - INFO - ============================================================
2026-03-10 10:00:15 - INFO - Opening DBF file: C:\ALPHAERP\Empresas\RZAVALA\remd.dbf
2026-03-10 10:00:16 - INFO - Loaded 80 records from remd.dbf
2026-03-10 10:00:17 - INFO - Prepared 80 valid inventory records for sending
2026-03-10 10:00:18 - INFO - Processing inventory batch 1 (25 records)
2026-03-10 10:00:20 - INFO - API processed batch: 25/25 records successful
2026-03-10 10:00:21 - INFO - Processing inventory batch 2 (25 records)
2026-03-10 10:00:23 - INFO - API processed batch: 25/25 records successful
2026-03-10 10:00:24 - INFO - Processing inventory batch 3 (30 records)
2026-03-10 10:00:26 - INFO - API processed batch: 30/30 records successful
2026-03-10 10:00:27 - INFO - Total inventory codes sent: 80/80
2026-03-10 10:00:28 - INFO - ============================================================
2026-03-10 10:00:28 - INFO - ZAVALA DBF UPLOADER completed successfully
2026-03-10 10:00:28 - INFO - ============================================================
```

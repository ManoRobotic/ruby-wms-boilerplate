# API Documentation for Production Orders and Inventory Codes

This document provides comprehensive information about the API endpoints for synchronization, production orders, and inventory codes.

## Authentication

All API endpoints require authentication via company token. Provide the token in one of these ways:

**Header (Recommended):**

```
X-Company-Token: your_company_token_here
```

**Query Parameter:**

```
?company_token=your_company_token_here
```

### Getting Your Company Token

Use the Rails console in production:

```ruby
company = Company.find_by(name: "Your Company Name")
puts "Token: #{company.serial_auth_token}"
```

---

## Endpoints

### 1. Sync Status

Get the current count of production orders and inventory codes for your company.

**Endpoint:** `GET /api/production_orders/sync_status`  
**Alternative:** `GET /api/inventory_codes/sync_status`

Both endpoints return the same data.

**Headers:**

```
X-Company-Token: your_token_here
```

**Response:**

```json
{
  "company_name": "Flexiempaques",
  "production_orders_count": 150,
  "inventory_codes_count": 450,
  "last_no_opro": 12345
}
```

**cURL Example:**

```bash
curl -X GET "https://wms.fly.dev/api/production_orders/sync_status" \
  -H "X-Company-Token: f5284e6402cf64f9794711b91282e343"
```

---

### 2. Create Production Order

Create a single production order.

**Endpoint:** `POST /api/production_orders`

**Headers:**

```
X-Company-Token: your_token_here
Content-Type: application/json
```

**Request Body:**

```json
{
  "production_order": {
    "no_opro": "12345",
    "quantity_requested": 100,
    "product_key": "BOPP-35",
    "warehouse_id": "f7a1f77a-0802-49e3-871e-55bc917094f9",
    "priority": "medium",
    "status": "pending",
    "notes": "Optional notes",
    "lote_referencia": "LOTE-001",
    "ano": 2026
  }
}
```

**Response:**

```json
{
  "message": "Production order created successfully",
  "production_order": {
    "id": "uuid-here",
    "no_opro": "12345",
    "quantity_requested": 100,
    "status": "pending"
  }
}
```

**cURL Example:**

```bash
curl -X POST "https://wms.fly.dev/api/production_orders" \
  -H "X-Company-Token: f5284e6402cf64f9794711b91282e343" \
  -H "Content-Type: application/json" \
  -d '{
    "production_order": {
      "no_opro": "12345",
      "quantity_requested": 100,
      "product_key": "BOPP-35",
      "warehouse_id": "f7a1f77a-0802-49e3-871e-55bc917094f9"
    }
  }'
```

---

### 3. Batch Create Production Orders

Create multiple production orders in a single request.

**Endpoint:** `POST /api/production_orders/batch`

**Headers:**

```
X-Company-Token: your_token_here
Content-Type: application/json
```

**Request Body:**

```json
{
  "production_orders": [
    {
      "no_opro": "12345",
      "quantity_requested": 100,
      "product_key": "BOPP-35",
      "warehouse_id": "f7a1f77a-0802-49e3-871e-55bc917094f9"
    },
    {
      "no_opro": "12346",
      "quantity_requested": 200,
      "product_key": "BOPP-40",
      "warehouse_id": "f7a1f77a-0802-49e3-871e-55bc917094f9"
    }
  ]
}
```

**Response:**

```json
{
  "message": "Batch processing completed",
  "success_count": 2,
  "total_count": 2,
  "results": [
    {
      "index": 0,
      "status": "success",
      "message": "Production order created successfully",
      "production_order": {
        "id": "uuid-1",
        "order_number": null,
        "no_opro": "12345",
        "product_id": null,
        "quantity_requested": 100.0,
        "status": "pending"
      }
    },
    {
      "index": 1,
      "status": "success",
      "message": "Production order created successfully",
      "production_order": {
        "id": "uuid-2",
        "order_number": null,
        "no_opro": "12346",
        "product_id": null,
        "quantity_requested": 200.0,
        "status": "pending"
      }
    }
  ]
}
```

---

### 4. Create Inventory Code

Create a single inventory code.

**Endpoint:** `POST /api/inventory_codes`

**Headers:**

```
X-Company-Token: your_token_here
Content-Type: application/json
```

**Request Body:**

```json
{
  "inventory_code": {
    "no_ordp": "12345",
    "cve_copr": "COMP-001",
    "cve_prod": "PROD-001",
    "can_copr": 50.5,
    "costo": 25.5,
    "lote": "LOTE-001",
    "fech_cto": "2026-01-12",
    "tip_copr": 1
  }
}
```

**Response:**

```json
{
  "message": "Inventory code created successfully",
  "inventory_code": {
    "id": "uuid-here",
    "no_ordp": "12345",
    "cve_copr": "COMP-001",
    "cve_prod": "PROD-001"
  }
}
```

---

### 5. Batch Create Inventory Codes

Create multiple inventory codes in a single request.

**Endpoint:** `POST /api/inventory_codes/batch`

**Headers:**

```
X-Company-Token: your_token_here
Content-Type: application/json
```

**Request Body:**

```json
{
  "inventory_codes": [
    {
      "no_ordp": "12345",
      "cve_copr": "COMP-001",
      "cve_prod": "PROD-001",
      "can_copr": 50.5,
      "lote": "LOTE-001"
    },
    {
      "no_ordp": "12346",
      "cve_copr": "COMP-002",
      "cve_prod": "PROD-002",
      "can_copr": 75.0,
      "lote": "LOTE-002"
    }
  ]
}
```

**Response:**

```json
{
  "message": "Batch processing completed",
  "success_count": 2,
  "total_count": 2,
  "results": [
    {
      "index": 0,
      "status": "success",
      "message": "Inventory code created successfully",
      "inventory_code": {
        "id": "uuid-1",
        "no_ordp": "12345",
        "cve_copr": "COMP-001",
        "cve_prod": "PROD-001"
      }
    },
    {
      "index": 1,
      "status": "success",
      "message": "Inventory code created successfully",
      "inventory_code": {
        "id": "uuid-2",
        "no_ordp": "12346",
        "cve_copr": "COMP-002",
        "cve_prod": "PROD-002"
      }
    }
  ]
}
```

---

## Company Tokens Reference

### Flexiempaques

- **Device ID**: `device-serial-6bca882ac82e4333afedfb48ac3eea8e`
- **Token**: `f5284e6402cf64f9794711b91282e343`
- **Warehouse ID**: `1ac67bd3-d5b1-4bbb-9f33-31d4a71af536`

### Rzavala

- **Device ID**: `device-serial-bf05ebcf2c834539b2c63f542754282d`
- **Token**: `74bf5e0a6ae8813dfe80593ed84a7a9c`
- **Warehouse ID**: `f7a1f77a-0802-49e3-871e-55bc917094f9`

---

## Error Responses

### 401 Unauthorized

```json
{
  "error": "Unauthorized: Invalid company token"
}
```

### 400 Bad Request

```json
{
  "errors": ["Missing required parameter: no_ordp"]
}
```

### 422 Unprocessable Entity

```json
{
  "errors": ["No ordp can't be blank", "Cve copr can't be blank"]
}
```

---

## Python Example for CLI Assistant

```python
import requests

# Configuration
BASE_URL = "https://wms.fly.dev/api"
COMPANY_TOKEN = "74bf5e0a6ae8813dfe80593ed84a7a9c"  # Rzavala
WAREHOUSE_ID = "f7a1f77a-0802-49e3-871e-55bc917094f9"

headers = {
    "X-Company-Token": COMPANY_TOKEN,
    "Content-Type": "application/json"
}

# 1. Check sync status
response = requests.get(f"{BASE_URL}/production_orders/sync_status", headers=headers)
status = response.json()
print(f"Current counts: {status['production_orders_count']} orders, {status['inventory_codes_count']} codes")

# 2. Create a production order
order_data = {
    "production_order": {
        "no_opro": "12347",
        "quantity_requested": 150,
        "product_key": "BOPP-50",
        "warehouse_id": WAREHOUSE_ID
    }
}
response = requests.post(f"{BASE_URL}/production_orders", headers=headers, json=order_data)
print(f"Order created: {response.json()}")

# 3. Batch create inventory codes
codes_data = {
    "inventory_codes": [
        {
            "no_ordp": "12347",
            "cve_copr": "COMP-100",
            "cve_prod": "PROD-100",
            "can_copr": 100.0,
            "lote": "LOTE-100"
        }
    ]
}
response = requests.post(f"{BASE_URL}/inventory_codes/batch", headers=headers, json=codes_data)
print(f"Codes created: {response.json()}")
```

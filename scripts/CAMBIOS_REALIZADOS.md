# Resumen de Cambios - Fix admin_id en Production Orders

## Problema
Las órdenes de producción creadas para Zavala no se mostraban en la UI porque:
1. No tenían `admin_id` asignado
2. El controller filtra por `admin_id` para admins que no son `super_admin`

## Solución Implementada

### 1. Modelo ProductionOrder (`app/models/production_order.rb`)
**Cambio:** Agregado callback `before_validation :auto_assign_admin`

```ruby
# Línea 68: Nuevo callback
before_validation :auto_assign_admin

# Líneas 269-279: Método para auto-asignar admin
def auto_assign_admin
  # Auto-assign admin_id if not set to ensure orders are visible in UI
  return if admin_id.present?
  return unless company_id.present?

  first_admin = company.admins.first
  if first_admin
    self.admin = first_admin
    Rails.logger.debug "Auto-assigned admin #{first_admin.id} to production order"
  end
end
```

**Beneficio:** Todas las órdenes creadas tendrán automáticamente el primer admin de su compañía.

---

### 2. Controller API (`app/controllers/api/production_orders_controller.rb`)
**Cambio:** Mejorado el fallback para asignar `admin_id` en el método `batch`

```ruby
# Líneas 207-217: Verificación explícita con logging
if production_order.admin_id.blank?
  first_admin = target_company.admins.first
  if first_admin
    production_order.admin = first_admin
    Rails.logger.info "Auto-assigned admin_id #{first_admin.id} to production order"
  else
    Rails.logger.warn "No admin found for company #{target_company.name} - orders may not be visible in UI"
  end
end
```

**Beneficio:** Doble protección desde el controller + logging para debugging.

---

### 3. Script para Crear Órdenes (`scripts/create_zavala_orders_console.rb`)
**Cambios:**
1. Busca y asigna el admin de Zavala explícitamente
2. Incluye `admin: admin` al crear las órdenes
3. Limpia el cache del dashboard después de crear

```ruby
# Línea 23: Buscar admin de Zavala
admin = Admin.find_by(company_id: COMPANY_ID) || Admin.first

# Línea 54: Asignar admin al crear
admin: admin,  # Asignar admin_id para que sea visible en la UI
```

**Beneficio:** Las órdenes creadas manualmente desde consola serán visibles inmediatamente.

---

## Verificación de Sintaxis

```bash
# Ruby syntax check
ruby -c app/models/production_order.rb           # Syntax OK ✓
ruby -c app/controllers/api/production_orders_controller.rb  # Syntax OK ✓
```

---

## ¿Por qué no pasó esto en Flexiempaques?

1. **Flexiempaques tiene admins configurados como `super_admin`** - Ellos ven todas las órdenes de su compañía sin necesidad de `admin_id`
2. **Las órdenes se sincronizan desde Google Sheets/Excel** - Ese proceso ya asignaba `admin_id` correctamente
3. **Las órdenes se crean desde la UI** - La UI asigna automáticamente el `admin_id` del usuario logueado

---

## ¿Cómo evitar este problema en el futuro?

### Para órdenes creadas desde scripts/consola:
```ruby
# Siempre asignar admin_id explícitamente
admin = Admin.find_by(company_id: company_id)
ProductionOrder.create!(
  # ... otros campos ...
  admin: admin,
  company_id: company_id
)
```

### Para nuevas compañías:
1. Asegurarse de crear al menos un admin para la compañía
2. Opcionalmente, configurar el admin como `super_admin` si tendrá múltiples usuarios

```ruby
admin = Admin.create!(
  email: "admin@empresa.com",
  password: "password123",
  company_id: company_id,
  super_admin_role: "admin"  # Esto permite ver todas las órdenes de la compañía
)
```

---

## Archivos Modificados

1. `app/models/production_order.rb` - Callback auto_assign_admin
2. `app/controllers/api/production_orders_controller.rb` - Fallback mejorado en batch
3. `scripts/create_zavala_orders_console.rb` - Asignación explícita de admin_id

---

## Pruebas Recomendadas

1. **En producción, ejecutar:**
```bash
bin/rails runner scripts/repair_zavala_orders.rb
```

2. **Verificar en la UI:**
   - Iniciar sesión como `admin@rzavala.com`
   - Ir a `/admin/production_orders`
   - Deberían verse las 15 órdenes creadas

3. **Probar dbf_uploader.py:**
   - Ejecutar el uploader
   - Verificar que las nuevas órdenes aparezcan en la UI

---

## Notas Importantes

- El callback `auto_assign_admin` solo se ejecuta si `admin_id` está vacío y hay un `company_id` válido
- Si una compañía no tiene admins, el callback no asigna nada (pero el controller ya maneja ese caso)
- El logging ayuda a debuggear problemas futuros de asignación de admin_id

module Admin::ProductionOrdersHelper
  # Helper to generate the edit form for a consecutivo
  def edit_consecutivo_form(production_order, production_order_item)
    form_with model: [:admin, production_order, production_order_item], 
              local: true, 
              data: { controller: "consecutivo-form", action: "submit->consecutivo-form#handleFormSubmit" },
              class: "relative border-t border-slate-200 py-2" do |form|
      
      concat content_tag(:div, class: "grid gap-2 mb-2") do
        # Folio Consecutivo
        concat content_tag(:div) do
          concat content_tag(:label, "Folio Consecutivo", class: "block mb-1 text-sm font-medium text-slate-700")
          concat content_tag(:div, class: "flex items-center gap-2") do
            concat form.text_field :folio_consecutivo, 
                      class: "bg-slate-50 border border-slate-300 text-slate-700 text-sm rounded-lg block w-full p-2",
                      readonly: true
          end
        end

        # Product Name (Pre-filled with clave_producto)
        concat content_tag(:div) do
          concat content_tag(:label, "Clave Producto", for: "clave_producto", class: "block mb-1 text-sm font-medium text-slate-700")
          concat form.text_field :clave_producto_display, 
                    name: "clave_producto_display",
                    id: "clave_producto", 
                    class: "bg-slate-50 border border-slate-300 text-slate-700 text-sm rounded-lg focus:ring-emerald-500 focus:border-emerald-500 block w-full p-2",
                    value: production_order.clave_producto || "BOPPTRANS 35 / 420",
                    placeholder: "BOPPTRANS 35 / 420",
                    readonly: true
        end

        # Control de modo de pesaje
        concat content_tag(:div, class: "mb-3") do
          # Mensajes de modo
          concat content_tag(:div, data: { "consecutivo-form-target": "scaleWeightSection" }) do
            # Mensaje cuando está en modo báscula (por defecto)
            concat content_tag(:p, class: "text-sm text-amber-700 bg-amber-50 border border-amber-200 rounded-md p-2 scale-mode-message") do
              concat content_tag(:span, "Modo Báscula Activo:", class: "font-medium")
              concat " Use el control de pesaje abajo para obtener el peso automáticamente."
            end
            
            # Mensaje cuando está en modo manual (oculto por defecto)
            concat content_tag(:p, class: "text-sm text-blue-700 bg-blue-50 border border-blue-200 rounded-md p-2 manual-mode-message hidden") do
              concat content_tag(:span, "Modo de Uso:", class: "font-medium")
              concat " Ingreso manual, ingrese peso del folio manualmente."
            end
          end
          
          # Checkbox moved here
          concat content_tag(:div, class: "flex items-center mt-1") do
            concat content_tag(:label, class: "flex items-center cursor-pointer") do
              concat check_box_tag "", "", false, 
                        class: "h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded",
                        data: { action: "change->consecutivo-form#toggleManualMode", "consecutivo-form-target": "manualModeCheckbox" }
              concat content_tag(:span, "Ingresar peso manualmente", class: "ml-2 text-sm font-medium text-gray-700")
            end
          end

          # Input de peso manual (deshabilitado por defecto)
          concat content_tag(:div, "", data: { "consecutivo-form-target": "manualWeightSection" }, class: "hidden") do
            concat content_tag(:label, "Peso Bruto (kg)", class: "block mb-1 text-sm font-medium text-slate-700 mt-4")
            concat content_tag(:div, class: "flex items-center") do
              concat form.number_field :peso_bruto, 
                        class: "bg-slate-50 border border-slate-300 text-slate-700 text-sm rounded-lg focus:ring-emerald-500 focus:border-emerald-500 block w-full p-2",
                        placeholder: "0.00",
                        step: 0.01,
                        min: 0,
                        disabled: true,
                        data: { 
                          action: "input->consecutivo-form#calculateWeights",
                          "consecutivo-form-target": "pesoBrutoInput"
                        }
            end
            concat content_tag(:p, "Ingrese el peso manualmente", class: "text-xs text-gray-600 mt-1")
          end
        end

        # Componente de Pesaje
        concat content_tag(:div, class: "bg-gray-50 rounded-md p-2 mb-2 transition-opacity duration-300", 
                 data: { controller: "serial", "serial-base-url-value": "/api/serial", "serial-auto-connect-value": "false", "consecutivo-form-target": "serialSection" }) do
          concat content_tag(:h4, "Control de Pesaje", class: "font-medium text-gray-700 mb-1.5 text-sm")
          
          # Status de Conexión
          concat content_tag(:div, class: "flex items-center justify-between mb-1.5") do
            concat content_tag(:span, "Estado:", class: "text-sm font-medium text-gray-600")
            concat content_tag(:span, "Desconectado", data: { "serial-target": "status" }, class: "px-2 py-1 rounded text-xs font-medium bg-blue-100 text-blue-800")
          end

          # Weight Display
          concat content_tag(:div, class: "weight-section p-2 bg-white rounded-md border mb-2") do
            concat content_tag(:div, class: "flex items-center justify-between mb-1.5") do
              concat content_tag(:span, "Peso actual:", class: "font-medium text-gray-700 text-sm")
              concat content_tag(:div, class: "flex gap-1") do
                concat content_tag(:button, "Conectar", 
                          data: { action: "click->serial#connectScale" },
                          type: "button",
                          class: "px-2 py-1 bg-blue-600 text-white text-xs rounded hover:bg-blue-700 transition-all duration-200")
                concat content_tag(:button, "Leer ahora", 
                          data: { action: "click->serial#readWeightNow" },
                          type: "button",
                          class: "px-2 py-1 text-xs border border-gray-300 rounded hover:bg-gray-50 transition-all duration-200")
              end
            end
            concat content_tag(:div, data: { "serial-target": "weight" }, class: "weight-display") do
              concat content_tag(:div, "--", class: "text-2xl font-bold block text-center transition-all duration-300 ease-in-out text-gray-400")
              concat content_tag(:div, "--", class: "text-sm text-gray-500 block text-center")
            end
            
            # Botón para usar peso en el formulario
            concat content_tag(:button, "Usar este peso", 
                      type: "button",
                      data: { action: "click->consecutivo-form#useSerialWeight" },
                      class: "w-full mt-1.5 px-2 py-1 bg-emerald-600 text-white text-sm rounded-md hover:bg-emerald-700 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed",
                      disabled: true)
          end
        end

        # Campos calculados automáticamente
        concat content_tag(:div, class: "bg-emerald-50 rounded-md p-2 mb-2") do
          concat content_tag(:h4, "Cálculos Automáticos", class: "text-sm font-semibold text-emerald-900 mb-1.5")
          
          concat content_tag(:div, class: "grid grid-cols-2 gap-1.5") do
            # Peso Neto
            concat content_tag(:div, class: "bg-white rounded p-1.5 border border-emerald-200") do
              concat content_tag(:div, "Peso Neto", class: "text-xs text-emerald-600 font-medium")
              concat content_tag(:div, production_order_item.peso_neto ? "#{production_order_item.peso_neto.round(3)} kg" : "0.000 kg", 
                        data: { "consecutivo-form-target": "pesoNetoDisplay" }, 
                        class: "text-sm font-bold text-emerald-900")
              concat form.hidden_field :peso_neto, data: { "consecutivo-form-target": "pesoNeto" }
            end

            # Peso Core
            concat content_tag(:div, class: "bg-white rounded p-1.5 border border-emerald-200") do
              concat content_tag(:div, "Peso Core", class: "text-xs text-emerald-600 font-medium")
              concat content_tag(:div, production_order_item.peso_core_gramos ? "#{production_order_item.peso_core_gramos} g" : "200 g", 
                        data: { "consecutivo-form-target": "pesoCoreDisplay" }, 
                        class: "text-sm font-bold text-emerald-900")
            end

            # Metros Lineales
            concat content_tag(:div, class: "bg-white rounded p-1.5 border border-emerald-200") do
              concat content_tag(:div, "Metros Lineales", class: "text-xs text-emerald-600 font-medium")
              concat content_tag(:div, production_order_item.metros_lineales ? "#{production_order_item.metros_lineales.round(4)} m" : "0.0000 m", 
                        data: { "consecutivo-form-target": "metrosLinealesDisplay" }, 
                        class: "text-sm font-bold text-emerald-900")
              concat form.hidden_field :metros_lineales, data: { "consecutivo-form-target": "metrosLineales" }
            end

            # Especificaciones
            concat content_tag(:div, class: "bg-white rounded p-1.5 border border-emerald-200") do
              concat content_tag(:div, "Especificaciones", class: "text-xs text-emerald-600 font-medium")
              concat content_tag(:div, "#{production_order_item.micras || 35}μ / #{production_order_item.ancho_mm || 420}mm", 
                        data: { "consecutivo-form-target": "especificacionesDisplay" }, 
                        class: "text-xs font-semibold text-emerald-900")
              concat form.hidden_field :micras
              concat form.hidden_field :ancho_mm
            end
          end

          concat content_tag(:div, "Los cálculos se actualizan automáticamente al ingresar el peso bruto", class: "text-xs text-emerald-700 mt-1.5 opacity-75")
        end
      end

      # Hidden fields for calculated values
      concat form.hidden_field :peso_core_gramos
      concat form.hidden_field :altura_cm, value: 75
      
      # Form buttons
      concat content_tag(:div, class: "flex shrink-0 flex-wrap items-center pt-2 justify-end border-t border-slate-200") do
        concat content_tag(:button, "Cancelar", 
                  data: { "dialog-close": "true" }, 
                  type: "button",
                  class: "rounded-md border border-transparent py-1 px-2.5 text-center text-sm transition-all text-slate-600 hover:bg-slate-100 focus:bg-slate-100 active:bg-slate-100 disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none")
        concat form.submit "Guardar Consecutivo", 
                  class: "rounded-md bg-emerald-600 py-1 px-2.5 border border-transparent text-center text-sm text-white transition-all shadow hover:shadow focus:bg-emerald-700 focus:shadow-none active:bg-emerald-700 hover:bg-emerald-700 active:shadow-none disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none ml-1.5"
      end
    end
  end
end
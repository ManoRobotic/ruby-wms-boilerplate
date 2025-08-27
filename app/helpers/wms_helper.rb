module WmsHelper
  # Status badge helpers
  def status_badge(status, type = :default)
    color_class = status_color_class(status, type)
    content_tag :span, status.humanize, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{color_class}"
  end

  def priority_badge(priority)
    color_class = case priority&.to_s
    when "urgent" then "bg-red-100 text-red-800"
    when "high" then "bg-orange-100 text-orange-800"
    when "medium" then "bg-yellow-100 text-yellow-800"
    when "low" then "bg-green-100 text-green-800"
    else "bg-gray-100 text-gray-800"
    end

    content_tag :span, priority&.humanize || "Unknown", class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{color_class}"
  end

  def utilization_bar(percentage)
    color_class = case percentage
    when 0..50 then "bg-green-500"
    when 51..80 then "bg-yellow-500"
    else "bg-red-500"
    end

    content_tag :div, class: "w-full bg-gray-200 rounded-full h-2.5" do
      content_tag :div, "", class: "#{color_class} h-2.5 rounded-full", style: "width: #{percentage}%"
    end
  end

  # Formatting helpers
  def format_currency(amount)
    return "$0.00" unless amount
    "$#{number_with_delimiter(amount, delimiter: ',', precision: 2)}"
  end

  def format_weight(weight_in_kg)
    return "N/A" unless weight_in_kg
    if weight_in_kg < 1
      "#{(weight_in_kg * 1000).round}g"
    else
      "#{weight_in_kg}kg"
    end
  end

  def format_dimensions(dimensions_hash)
    return "N/A" unless dimensions_hash.is_a?(Hash) && dimensions_hash.any?

    length = dimensions_hash["length"] || dimensions_hash[:length]
    width = dimensions_hash["width"] || dimensions_hash[:width]
    height = dimensions_hash["height"] || dimensions_hash[:height]

    return "N/A" unless length && width && height

    "#{length} × #{width} × #{height} cm"
  end

  def format_duration(seconds)
    return "N/A" unless seconds

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60

    if hours > 0
      "#{hours.to_i}h #{minutes.to_i}m"
    else
      "#{minutes.to_i}m"
    end
  end

  # Icon helpers
  def wms_icon(name, options = {})
    default_class = "h-5 w-5"
    css_class = [ default_class, options[:class] ].compact.join(" ")

    case name.to_s
    when "warehouse"
      content_tag :svg, class: css_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, "", d: "M4 3a2 2 0 100 4h12a2 2 0 100-4H4z M3 8a2 2 0 00-2 2v6a2 2 0 002 2h14a2 2 0 002-2v-6a2 2 0 00-2-2H3zm5 4a2 2 0 114 0 2 2 0 01-4 0z"
      end
    when "location"
      content_tag :svg, class: css_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, "", 'fill-rule': "evenodd", d: "M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z", 'clip-rule': "evenodd"
      end
    when "task"
      content_tag :svg, class: css_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, "", d: "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
      end
    when "pick_list"
      content_tag :svg, class: css_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, "", d: "M9 5H7a2 2 0 00-2 2v6a2 2 0 002 2h6a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"
      end
    when "inventory"
      content_tag :svg, class: css_class, fill: "currentColor", viewBox: "0 0 20 20" do
        content_tag :path, "", 'fill-rule': "evenodd", d: "M10 2L3 7v11a1 1 0 001 1h12a1 1 0 001-1V7l-7-5zM8.5 13a1.5 1.5 0 103 0 1.5 1.5 0 00-3 0z", 'clip-rule': "evenodd"
      end
    else
      content_tag :span, "●", class: css_class
    end
  end

  # Navigation helpers
  def wms_nav_item(name, path, icon = nil)
    is_active = current_page?(path) || request.path.start_with?(path)

    link_to path, class: nav_item_class(is_active) do
      content = []
      content << wms_icon(icon, class: "mr-3 h-6 w-6") if icon
      content << content_tag(:span, name)
      safe_join(content)
    end
  end

  def wms_menu_items(current_user, current_admin)
    all_menu_items = [
      { path: admin_path, icon: 'gauge-high', label: t('admin.sidebar.dashboard'), permission: 'read_admin_dashboard' },
      { path: admin_orders_path, icon: 'truck-fast', label: t('admin.sidebar.orders'), permission: 'read_orders' },
      { path: admin_production_orders_path, icon: 'industry', label: 'Ordenes de Producción', permission: 'read_production_orders' },
      { path: admin_inventory_codes_path, icon: 'barcode', label: 'Códigos de Inventario', permission: 'read_inventory_codes' },
      { path: admin_products_path, icon: 'cart-shopping', label: t('admin.sidebar.products'), permission: 'read_products' },
      { path: admin_categories_path, icon: 'list', label: t('admin.sidebar.categories'), permission: 'manage_categories' },
      { path: admin_warehouses_path, icon: 'warehouse', label: t('admin.sidebar.warehouses'), permission: 'read_warehouse' },
      { path: admin_tasks_path, icon: 'tasks', label: t('admin.sidebar.tasks'), permission: 'read_tasks' },
      { path: admin_pick_lists_path, icon: 'clipboard-list', label: t('admin.sidebar.pick_lists'), permission: 'read_pick_lists' },
      { path: admin_users_path, icon: 'users', label: t('admin.sidebar.users'), permission: 'manage_users' },
      { path: admin_inventory_transactions_path, icon: 'arrow-right-arrow-left', label: t('admin.sidebar.inventory_transactions'), permission: 'read_inventory' },
      { path: admin_receipts_path, icon: 'truck-ramp-box', label: t('admin.sidebar.receipts'), permission: 'manage_receipts' },
      { path: admin_cycle_counts_path, icon: 'calculator', label: t('admin.sidebar.cycle_counts'), permission: 'manage_inventory' },
      { path: admin_shipments_path, icon: 'shipping-fast', label: t('admin.sidebar.shipments'), permission: 'manage_shipments' },
      { path: admin_manual_printing_path, icon: 'print', label: t('admin.sidebar.manual_printing'), permission: 'manage_manual_printing' },
      { path: admin_configurations_path, icon: 'gear', label: 'Configuraciones', permission: 'admin_settings' }
    ]

    if current_user&.operador? || current_user&.supervisor?
      # Para operadores y supervisores de rzavala, restringir los elementos del menú
      if current_user.super_admin_role == 'rzavala'
        allowed_labels = [
          'Panel de Control',
          'Ordenes de Producción',
          'Impresión Manual',
          'Códigos de Inventario'
        ]
        
        all_menu_items.select do |item|
          allowed_labels.include?(item[:label]) && can?(item[:permission])
        end
      else
        # Para otros operadores y supervisores, mantener el comportamiento actual
        if current_user&.operador?
          all_menu_items.select do |item|
            can?(item[:permission]) && item[:label] != t('admin.sidebar.orders')
          end
        else
          # Para supervisores que no son de rzavala, aplicar permisos normales
          all_menu_items.select do |item|
            can?(item[:permission])
          end
        end
      end
    else
      all_menu_items.select do |item|
        current_admin || can?(item[:permission])
      end
    end
  end

  def nav_item_class(active = false)
    base_class = "group flex items-center px-2 py-2 text-sm font-medium rounded-md"

    if active
      "#{base_class} bg-gray-100 text-gray-900"
    else
      "#{base_class} text-gray-600 hover:bg-gray-50 hover:text-gray-900"
    end
  end

  # Table helpers
  def sortable_column(column, title = nil)
    title ||= column.humanize
    direction = column == params[:sort] && params[:direction] == "asc" ? "desc" : "asc"

    link_to title, request.query_parameters.merge(sort: column, direction: direction),
            class: "group inline-flex"
  end

  def empty_state(title, description, action_text = nil, action_path = nil)
    content_tag :div, class: "text-center py-12" do
      content = []
      content << content_tag(:div, wms_icon("inventory", class: "mx-auto h-12 w-12 text-gray-400"))
      content << content_tag(:h3, title, class: "mt-2 text-sm font-medium text-gray-900")
      content << content_tag(:p, description, class: "mt-1 text-sm text-gray-500")

      if action_text && action_path
        content << content_tag(:div, class: "mt-6") do
          link_to action_text, action_path,
                  class: "inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
        end
      end

      safe_join(content)
    end
  end

  # Metric helpers
  def metric_card(title, value, change = nil, trend = nil)
    content_tag :div, class: "bg-white overflow-hidden shadow rounded-lg" do
      content_tag :div, class: "p-5" do
        content = []

        content << content_tag(:div, class: "flex items-center") do
          content_tag(:div, class: "flex-1") do
            parts = []
            parts << content_tag(:dl) do
              dt = content_tag(:dt, title, class: "text-sm font-medium text-gray-500 truncate")
              dd = content_tag(:dd, value, class: "mt-1 text-3xl font-semibold text-gray-900")
              dt + dd
            end
            safe_join(parts)
          end
        end

        if change && trend
          content << content_tag(:div, class: "mt-4 flex items-center text-sm") do
            trend_class = trend == "up" ? "text-green-600" : "text-red-600"
            trend_icon = trend == "up" ? "↗" : "↘"

            span1 = content_tag(:span, "#{trend_icon} #{change}", class: trend_class)
            span2 = content_tag(:span, " from last month", class: "text-gray-500")
            span1 + span2
          end
        end

        safe_join(content)
      end
    end
  end

  # Alert helpers
  def alert_count_badge(count)
    return "" if count.zero?

    color_class = case count
    when 1..5 then "bg-yellow-100 text-yellow-800"
    when 6..10 then "bg-orange-100 text-orange-800"
    else "bg-red-100 text-red-800"
    end

    content_tag :span, count, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{color_class}"
  end

  private

  def status_color_class(status, type)
    case type
    when :task
      case status&.to_s
      when "pending" then "bg-gray-100 text-gray-800"
      when "assigned" then "bg-blue-100 text-blue-800"
      when "in_progress" then "bg-yellow-100 text-yellow-800"
      when "completed" then "bg-green-100 text-green-800"
      when "cancelled" then "bg-red-100 text-red-800"
      else "bg-gray-100 text-gray-800"
      end
    when :pick_list
      case status&.to_s
      when "pending" then "bg-gray-100 text-gray-800"
      when "assigned" then "bg-blue-100 text-blue-800"
      when "in_progress" then "bg-yellow-100 text-yellow-800"
      when "completed" then "bg-green-100 text-green-800"
      when "cancelled" then "bg-red-100 text-red-800"
      else "bg-gray-100 text-gray-800"
      end
    when :order
      case status&.to_s
      when "pending" then "bg-gray-100 text-gray-800"
      when "allocated" then "bg-blue-100 text-blue-800"
      when "picked" then "bg-yellow-100 text-yellow-800"
      when "packed" then "bg-purple-100 text-purple-800"
      when "shipped" then "bg-indigo-100 text-indigo-800"
      when "delivered" then "bg-green-100 text-green-800"
      when "cancelled" then "bg-red-100 text-red-800"
      else "bg-gray-100 text-gray-800"
      end
    else
      "bg-gray-100 text-gray-800"
    end
  end
end

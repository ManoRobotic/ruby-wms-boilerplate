module ApplicationHelper
  def generate_breadcrumbs
    # Divide la URL actual en segmentos, excluyendo parámetros o rutas no deseadas
    segments = request.fullpath.split("/").reject(&:blank?)

    # Construye los enlaces acumulativos
    breadcrumbs = []
    segments.each_with_index do |segment, index|
      # Convierte el segmento en un título legible (Capitalización, sin guiones, etc.)
      title = segment.titleize

      # Genera la ruta acumulativa
      path = "/" + segments[0..index].join("/")

      # Agrega el título y ruta al breadcrumb
      breadcrumbs << { title: title, path: path }
    end

    breadcrumbs
  end

  # Helper for image with initials fallback
  def image_with_initials(object, css_classes = "object-cover w-12 h-12 rounded-full")
    if object.image_url.present?
      image_tag(object.image_url, alt: object.name, class: css_classes)
    else
      initials = extract_initials(object.name)
      content_tag(:div, class: "#{css_classes} bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center text-white font-bold") do
        content_tag(:span, initials, class: "text-sm")
      end
    end
  end

  private

  def extract_initials(name)
    return "?" if name.blank?
    
    words = name.strip.split(/\s+/)
    if words.length >= 2
      "#{words.first[0].upcase}#{words.last[0].upcase}"
    else
      words.first[0, 2].upcase
    end
  end
end

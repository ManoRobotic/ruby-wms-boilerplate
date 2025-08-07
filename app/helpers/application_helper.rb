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
    # Check for different image storage methods
    image_source = get_image_source(object)

    if image_source.present?
      image_tag(image_source, alt: object.name, class: css_classes)
    else
      initials = extract_initials(object.name)
      content_tag(:div, class: "#{css_classes} bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center text-white font-bold") do
        content_tag(:span, initials, class: "text-sm")
      end
    end
  end

  private

  def get_image_source(object)
    # Priority: Active Storage first, then image_url as fallback
    if object.respond_to?(:image) && object.image.attached?
      # Active Storage - single image (Category)
      url_for(object.image)
    elsif object.respond_to?(:images) && object.images.attached? && object.images.any?
      # Active Storage - multiple images (Product) - use first image
      url_for(object.images.first)
    elsif object.respond_to?(:image_url) && object.image_url.present? && valid_image_url?(object.image_url)
      # Traditional image_url attribute - only if URL is valid
      object.image_url
    else
      nil
    end
  rescue
    # Return nil if there's any error generating the URL
    nil
  end

  def valid_image_url?(url)
    # For now, skip URL validation to show initials for broken URLs
    # You can enable this later if needed
    false
  end

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

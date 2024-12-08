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
end

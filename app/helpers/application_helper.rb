module ApplicationHelper
    def breadcrumb(*segments)
        segments.unshift(link_to('Home', root_path))
      
        content_tag(:nav, class: "flex px-5 py-3 text-gray-700 border border-gray-200 rounded-lg bg-gray-50 dark:bg-gray-800 dark:border-gray-700") do
          content_tag(:ol, class: "inline-flex items-center space-x-1 md:space-x-2 rtl:space-x-reverse") do
            segments.each_with_index.map do |segment, index|
              unless segment.is_a?(Hash)
                raise ArgumentError, "Expected segment to be a Hash, but got #{segment.class}."
              end
      
              if index == segments.length - 1
                # Último segmento (actual)
                content_tag(:li, class: "inline-flex items-center") do
                  content_tag(:div, class: "flex items-center") do
                    concat content_tag(:svg, "", class: "rtl:rotate-180 w-3 h-3 mx-1 text-gray-400", viewBox: "0 0 6 10") do
                      concat content_tag(:path, nil, stroke: "currentColor", stroke_linecap: "round", stroke_linejoin: "round", stroke_width: 2, d: "m1 9 4-4-4-4")
                    end
                    concat content_tag(:span, segment[:label], class: "ms-1 text-sm font-medium text-gray-500 md:ms-2 dark:text-gray-400")
                  end
                end
              else
                # Segmentos intermedios (enlace)
                content_tag(:li, class: "inline-flex items-center") do
                  if segment[:url].is_a?(ActiveSupport::SafeBuffer)
                    concat segment[:url] # Usar el contenido de SafeBuffer tal cual
                  else
                    concat link_to(segment[:label], segment[:url], class: "inline-flex items-center text-sm font-medium text-gray-700 hover:text-blue-600 dark:text-gray-400 dark:hover:text-white")
                  end
                  concat content_tag(:svg, "", class: "rtl:rotate-180 block w-3 h-3 mx-1 text-gray-400", viewBox: "0 0 6 10") do
                    concat content_tag(:path, nil, stroke: "currentColor", stroke_linecap: "round", stroke_linejoin: "round", stroke_width: 2, d: "m1 9 4-4-4-4")
                  end
                end
              end
            end.join.html_safe
          end
        end
      end
      
end

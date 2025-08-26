class MakeWorksheetGidOptional < ActiveRecord::Migration[8.0]
  def change
    # No necesitamos cambiar nada en la base de datos, 
    # ya que worksheet_gid ya es nullable por defecto
    # Esta migración es solo para documentación
    
    # Opcional: agregar comentario explicativo
    reversible do |dir|
      dir.up do
        # worksheet_gid ahora es opcional - el sistema auto-detecta la hoja correcta
      end
    end
  end
end

class ConfirmPrintModalComponent < ViewComponent::Base
  def initialize(title: "Confirmar Impresión", message: "¿Está seguro que desea imprimir las etiquetas seleccionadas?")
    @title = title
    @message = message
  end
end
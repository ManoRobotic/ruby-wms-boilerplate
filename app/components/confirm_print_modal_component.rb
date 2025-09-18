class ConfirmPrintModalComponent < ViewComponent::Base
  def initialize(title: "Confirmar Impresión", message: "¿Está seguro que desea imprimir las etiquetas seleccionadas?", controller: "production-order-item")
    @title = title
    @message = message
    @controller = controller
  end
end
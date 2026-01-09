class ConsecutivoFormComponent < ViewComponent::Base
  def initialize(production_order:, consecutivo_form:, auto_print: false)
    @production_order = production_order
    @consecutivo_form = consecutivo_form
    @auto_print = auto_print
  end

  private

  attr_reader :production_order, :consecutivo_form, :auto_print
end

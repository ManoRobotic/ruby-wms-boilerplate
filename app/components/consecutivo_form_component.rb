class ConsecutivoFormComponent < ViewComponent::Base
  def initialize(production_order:, consecutivo_form:)
    @production_order = production_order
    @consecutivo_form = consecutivo_form
  end

  private

  attr_reader :production_order, :consecutivo_form
end

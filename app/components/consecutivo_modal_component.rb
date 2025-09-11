class ConsecutivoModalComponent < ViewComponent::Base
  def initialize(production_order:)
    @production_order = production_order
  end

  private

  attr_reader :production_order
end

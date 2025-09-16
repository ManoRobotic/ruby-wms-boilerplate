class ConfirmProductionOrderPrintComponent < ViewComponent::Base
  def initialize(production_order:, item_ids: [])
    @production_order = production_order
    @item_ids = item_ids
  end
end
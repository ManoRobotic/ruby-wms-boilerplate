require 'rails_helper'

RSpec.describe ProductionOrderItem, type: :model do
  describe "natural sorting of folios" do
    let(:production_order) { create(:production_order, order_number: "PO12345", no_opro: "12345") }
    
    it "sorts folios with different suffix lengths correctly" do
      # Mock the production order items to avoid full factory complexity if possible
      # or just use create if factories are well defined
      create(:production_order_item, production_order: production_order, folio_consecutivo: "FE-CR-1201260001-9")
      create(:production_order_item, production_order: production_order, folio_consecutivo: "FE-CR-1201260001-11")
      create(:production_order_item, production_order: production_order, folio_consecutivo: "FE-CR-1201260001-12")
      
      sorted_folios = production_order.production_order_items
                                     .order(Arel.sql("LENGTH(folio_consecutivo) DESC, folio_consecutivo DESC"))
                                     .pluck(:folio_consecutivo)
      
      expect(sorted_folios).to eq([
        "FE-CR-1201260001-12",
        "FE-CR-1201260001-11",
        "FE-CR-1201260001-9"
      ])
    end
  end
end

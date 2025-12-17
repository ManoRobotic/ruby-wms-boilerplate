require 'rails_helper'

RSpec.describe Admin::ProductionOrderItemsController, type: :controller do
  let(:company) { create(:company, serial_service_url: 'http://test-serial-service') }
  let(:admin) { create(:admin, company: company) }
  let(:production_order) { create(:production_order, company: company) }
  let(:item1) { create(:production_order_item, production_order: production_order) }
  let(:item2) { create(:production_order_item, production_order: production_order) }

  before do
    sign_in admin
    allow(SerialCommunicationService).to receive(:health_check).and_return(true)
  end

  describe "POST #confirm_print" do
    let(:params) { { production_order_id: production_order.id, item_ids: "#{item1.id},#{item2.id}", format: :turbo_stream } }

    context "when printing is successful" do
      before do
        allow(SerialCommunicationService).to receive(:print_label).and_return(true)
      end

      it "marks items as printed" do
        post :confirm_print, params: params
        
        expect(item1.reload.print_status).to eq('printed')
        expect(item2.reload.print_status).to eq('printed')
      end

      it "returns success message" do
        post :confirm_print, params: params
        expect(response).to have_http_status(:success)
      end
    end

    context "when printing fails and retry also fails" do
      before do
        allow(SerialCommunicationService).to receive(:print_label).and_return(false)
        allow(SerialCommunicationService).to receive(:connect_printer).and_return(true)
      end

      it "does NOT mark items as printed" do
        post :confirm_print, params: params
        
        expect(item1.reload.print_status).not_to eq('printed')
        expect(item2.reload.print_status).not_to eq('printed')
      end

      it "calls connect_printer for retry" do
        expect(SerialCommunicationService).to receive(:connect_printer).at_least(:once)
        post :confirm_print, params: params
      end
    end

    context "when printing fails initially but retry succeeds" do
      before do
        # First call fails, second call succeeds for each item
        # We need to be careful with how many times it's called. 
        # For 2 items: 
        # Item 1: attempt 1 (fail) -> connect -> attempt 2 (success)
        # Item 2: attempt 1 (fail) -> connect -> attempt 2 (success)
        
        # Simulating this behavior with a counter or sequence might be complex, 
        # so let's just make the first N calls fail and subsequent succeed?
        # Or checking that connect_printer is called.
        
        call_count = 0
        allow(SerialCommunicationService).to receive(:print_label) do
          call_count += 1
          call_count.even? # Fail on odd calls (1st attempt), succeed on even (2nd attempt)
        end
        
        allow(SerialCommunicationService).to receive(:connect_printer).and_return(true)
      end

      it "marks items as printed after retry" do
        post :confirm_print, params: params
        
        expect(item1.reload.print_status).to eq('printed')
        expect(item2.reload.print_status).to eq('printed')
      end

      it "attempts to connect printer" do
        expect(SerialCommunicationService).to receive(:connect_printer).at_least(:once)
        post :confirm_print, params: params
      end
    end
  end
end

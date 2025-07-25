require 'rails_helper'

RSpec.describe AdminController, type: :controller do
  let(:admin) { create(:admin) }

  before do
    sign_in admin
  end

  describe "GET #index" do
    let!(:fulfilled_order) { create(:order, :delivered, total: 100, created_at: 1.day.ago) }
    let!(:unfulfilled_orders) do
      (1..7).map do |i|
        create(:order, :pending, total: 50, created_at: i.days.ago)
      end
    end
    let!(:today_orders) { create_list(:order, 3, :delivered, total: 75, created_at: 30.minutes.ago) }

    before do
      # Create order products for per_sale calculation
      today_orders.each do |order|
        create(:order_product, order: order, quantity: 2)
      end
    end

    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end

    it "renders the admin layout" do
      get :index
      expect(response).to render_template(layout: "admin")
    end

    it "assigns recent unfulfilled orders" do
      get :index
      expect(assigns(:orders).count).to eq(5)
      expect(assigns(:orders)).to all(have_attributes(fulfilled: false))
      # Should return the 5 most recent (created 1-5 hours ago)
      expected_orders = unfulfilled_orders.sort_by(&:created_at).reverse.first(5)
      expect(assigns(:orders).pluck(:id)).to match_array(expected_orders.pluck(:id))
    end

    it "calculates quick stats for today" do
      get :index

      quick_stats = assigns(:quick_stats)
      expect(quick_stats[:sales]).to eq(3) # today_orders count
      expect(quick_stats[:revenue]).to eq(225) # 3 * 75
      expect(quick_stats[:avg_sale]).to eq(75.0)
      expect(quick_stats[:per_sale]).to eq(2.0) # average quantity
    end

    it "calculates revenue by day for last 7 days" do
      get :index

      revenue_by_day = assigns(:revenue_by_day)
      expect(revenue_by_day).to be_a(Hash)
      expect(revenue_by_day.keys.length).to eq(7)

      # Each entry should have Date as key and revenue as value
      revenue_by_day.each do |date, revenue|
        expect(date).to be_a(Date)
        expect(revenue).to be_a(Numeric)
      end
    end

    it "includes today's revenue in revenue_by_day" do
      get :index

      revenue_by_day = assigns(:revenue_by_day)
      today_data = revenue_by_day[Date.current]

      expect(today_data).to be_present
      expect(today_data).to eq(225) # today's total revenue
    end

    context "when no orders exist" do
      before do
        Order.destroy_all
      end

      it "handles empty data gracefully" do
        get :index

        expect(assigns(:orders)).to be_empty
        expect(assigns(:quick_stats)[:sales]).to eq(0)
        expect(assigns(:quick_stats)[:revenue]).to be_nil
        expect(assigns(:revenue_by_day)).to be_a(Hash)
      end
    end
  end

  describe "authentication" do
    context "when admin is not signed in" do
      before do
        sign_out admin
      end

      it "redirects to admin sign in" do
        get :index
        expect(response.location).to include("/admins/sign_in")
      end
    end
  end
end

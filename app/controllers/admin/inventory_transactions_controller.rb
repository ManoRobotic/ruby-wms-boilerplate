class Admin::InventoryTransactionsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_transaction, only: [ :show, :destroy ]

  def index
    @transactions = InventoryTransaction.includes(:warehouse, :location, :product, :admin)

    # Filters
    @transactions = @transactions.by_warehouse(params[:warehouse_id]) if params[:warehouse_id].present?
    @transactions = @transactions.by_location(params[:location_id]) if params[:location_id].present?
    @transactions = @transactions.by_product(params[:product_id]) if params[:product_id].present?
    @transactions = @transactions.by_type(params[:transaction_type]) if params[:transaction_type].present?
    @transactions = @transactions.by_admin(params[:admin_id]) if params[:admin_id].present?

    # Date range filter
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date]) rescue Date.current.beginning_of_month
      end_date = Date.parse(params[:end_date]) rescue Date.current
      @transactions = @transactions.by_date_range(start_date, end_date)
    else
      @transactions = @transactions.this_month
    end

    @transactions = @transactions.recent.page(params[:page]).per(50)

    # Summary stats
    @summary = {
      total_transactions: @transactions.count,
      inbound_value: @transactions.inbound.with_cost.sum("ABS(quantity) * unit_cost"),
      outbound_value: @transactions.outbound.with_cost.sum("ABS(quantity) * unit_cost"),
      net_quantity_change: @transactions.sum(:quantity)
    }
  end

  def show
    @related_stock = Stock.find_by(
      product: @transaction.product,
      location: @transaction.location,
      size: @transaction.size,
      batch_number: @transaction.batch_number
    )
  end

  def new
    @transaction = InventoryTransaction.new
    @warehouses = Warehouse.active
    @products = Product.active
    @transaction_types = InventoryTransaction::TRANSACTION_TYPES
  end

  def create
    @transaction = InventoryTransaction.new(transaction_params)
    @transaction.admin = current_admin

    if @transaction.save
      redirect_to admin_inventory_transaction_path(@transaction),
                  notice: "Inventory transaction was successfully created."
    else
      @warehouses = Warehouse.active
      @products = Product.active
      @transaction_types = InventoryTransaction::TRANSACTION_TYPES
      render :new
    end
  end

  def destroy
    if @transaction.created_at > 24.hours.ago && current_admin == @transaction.admin
      @transaction.destroy
      redirect_to admin_inventory_transactions_path,
                  notice: "Transaction was successfully deleted."
    else
      redirect_to admin_inventory_transaction_path(@transaction),
                  alert: "Cannot delete this transaction."
    end
  end

  # Reports
  def movement_report
    start_date = Date.parse(params[:start_date]) rescue 1.month.ago.to_date
    end_date = Date.parse(params[:end_date]) rescue Date.current

    @report = InventoryTransaction.inventory_movement_report(start_date, end_date)

    respond_to do |format|
      format.html
      format.json { render json: @report }
      format.csv do
        csv_data = generate_movement_report_csv(@report)
        send_data csv_data, filename: "inventory_movement_#{start_date}_to_#{end_date}.csv"
      end
    end
  end

  def daily_summary
    date = Date.parse(params[:date]) rescue Date.current
    @summary = InventoryTransaction.daily_summary(date)

    respond_to do |format|
      format.html
      format.json { render json: @summary }
    end
  end

  # Quick adjustment
  def quick_adjustment
    @adjustment = InventoryTransaction.new
    @warehouses = Warehouse.active
    @products = Product.active

    if params[:product_id] && params[:location_id]
      @product = Product.find(params[:product_id])
      @location = Location.find(params[:location_id])
      @current_stock = Stock.find_by(product: @product, location: @location)
    end
  end

  def create_adjustment
    product = Product.find(params[:product_id])
    location = Location.find(params[:location_id])
    quantity = params[:quantity].to_i
    reason = params[:reason]

    if quantity != 0
      transaction = InventoryTransaction.create_adjustment(
        product: product,
        quantity: quantity,
        location: location,
        admin: current_admin,
        reason: reason
      )

      if transaction.persisted?
        redirect_to admin_inventory_transactions_path,
                    notice: "Inventory adjustment created successfully."
      else
        redirect_to quick_adjustment_admin_inventory_transactions_path,
                    alert: "Could not create adjustment."
      end
    else
      redirect_to quick_adjustment_admin_inventory_transactions_path,
                  alert: "Quantity cannot be zero."
    end
  end

  private

  def set_transaction
    @transaction = InventoryTransaction.find(params[:id])
  end

  def transaction_params
    params.require(:inventory_transaction).permit(:warehouse_id, :location_id, :product_id,
                                                 :transaction_type, :quantity, :unit_cost,
                                                 :reason, :batch_number, :expiry_date, :size)
  end

  def generate_movement_report_csv(report)
    CSV.generate(headers: true) do |csv|
      csv << [ "Period", "Total Transactions", "Inbound Value", "Outbound Value", "Net Quantity Change" ]
      csv << [ report[:period], report[:total_transactions], report[:inbound_value],
              report[:outbound_value], report[:net_quantity_change] ]

      csv << []
      csv << [ "Top Products by Movement" ]
      csv << [ "Product", "Total Quantity Moved" ]

      report[:top_products].each do |product_name, quantity|
        csv << [ product_name, quantity ]
      end
    end
  end
end

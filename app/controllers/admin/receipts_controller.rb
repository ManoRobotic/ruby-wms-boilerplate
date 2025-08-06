class Admin::ReceiptsController < AdminController
  include StandardCrudResponses
  before_action :set_receipt, only: [ :show, :edit, :update, :destroy, :start_receiving, :complete ]

  def index
    @receipts = Receipt.includes(:warehouse, :admin, :receipt_items)
                      .order(created_at: :desc)
                      .page(params[:page])
                      .per(20)

    @receipts = @receipts.by_status(params[:status]) if params[:status].present?
    @receipts = @receipts.by_warehouse(params[:warehouse_id]) if params[:warehouse_id].present?
  end

  def show
    @receipt_items = @receipt.receipt_items.includes(:product)
  end

  def new
    @receipt = Receipt.new
    @warehouses = Warehouse.active
  end

  def create
    @receipt = Receipt.new(receipt_params)
    @receipt.admin = current_admin

    handle_create_response(
      @receipt,
      admin_receipts_path,
      "Recepción creada exitosamente.",
      :new,
      -> { @warehouses = Warehouse.active }
    )
  end

  def edit
    @warehouses = Warehouse.active
  end

  def update
    if @receipt.update(receipt_params)
      redirect_to admin_receipt_path(@receipt), notice: "Recepción actualizada exitosamente."
    else
      @warehouses = Warehouse.active
      render :edit
    end
  end

  def destroy
    if @receipt.scheduled? || @receipt.cancelled?
      @receipt.destroy
      redirect_to admin_receipts_path, notice: "Recepción eliminada exitosamente."
    else
      redirect_to admin_receipts_path, alert: "No se puede eliminar una recepción en proceso o completada."
    end
  end

  def start_receiving
    if @receipt.start_receiving!
      redirect_to admin_receipt_path(@receipt), notice: "Recepción iniciada exitosamente."
    else
      redirect_to admin_receipts_path, alert: "No se pudo iniciar la recepción."
    end
  end

  def complete
    if @receipt.complete!
      redirect_to admin_receipt_path(@receipt), notice: "Recepción completada exitosamente."
    else
      redirect_to admin_receipts_path, alert: "No se pudo completar la recepción."
    end
  end

  private

  def set_receipt
    @receipt = Receipt.find(params[:id])
  end

  def receipt_params
    params.require(:receipt).permit(:supplier_name, :warehouse_id, :reference_number,
                                   :expected_date, :received_date, :status, :notes, :total_items)
  end
end

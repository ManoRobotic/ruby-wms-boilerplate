class Admin::ReceiptItemsController < AdminController
  before_action :set_receipt
  before_action :set_receipt_item, only: [ :show, :edit, :update ]

  def show
    @related_transactions = InventoryTransaction.where(
      product: @receipt_item.product,
      reference: @receipt
    )
  end

  def edit
    # Only allow editing if receipt is in receiving status
    unless @receipt.status == "receiving"
      redirect_to admin_receipt_path(@receipt), alert: "No se puede editar este item."
      nil
    end
  end

  def update
    unless @receipt.status == "receiving"
      redirect_to admin_receipt_path(@receipt), alert: "No se puede editar este item."
      return
    end

    if @receipt_item.update(receipt_item_params)
      # Update receipt status if all items are received
      if @receipt.all_items_received?
        @receipt.update(status: "completed", completed_date: Date.current)
      end

      redirect_to admin_receipt_path(@receipt), notice: "Item actualizado exitosamente."
    else
      render :edit
    end
  end

  private

  def set_receipt
    @receipt = Receipt.find(params[:receipt_id])
  end

  def set_receipt_item
    @receipt_item = @receipt.receipt_items.find(params[:id])
  end

  def receipt_item_params
    params.require(:receipt_item).permit(:received_quantity, :unit_cost, :condition, :notes)
  end
end

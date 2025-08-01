class Admin::CycleCountItemsController < AdminController
  before_action :set_cycle_count
  before_action :set_cycle_count_item, only: [:show, :edit, :update]

  def show
    @related_stock = Stock.find_by(
      product: @cycle_count_item.product,
      location: @cycle_count_item.location
    )
    
    @recent_transactions = InventoryTransaction.where(
      product: @cycle_count_item.product,
      location: @cycle_count_item.location
    ).recent.limit(10)
  end

  def edit
    # Only allow editing if cycle count is in progress
    unless @cycle_count.status == 'in_progress'
      redirect_to admin_cycle_count_path(@cycle_count), alert: 'No se puede editar este item.'
      return
    end
  end

  def update
    unless @cycle_count.status == 'in_progress'
      redirect_to admin_cycle_count_path(@cycle_count), alert: 'No se puede editar este item.'
      return
    end

    if @cycle_count_item.update(cycle_count_item_params)
      # Check if all items are counted
      if @cycle_count.all_items_counted?
        @cycle_count.update(status: 'completed', completed_date: Date.current)
        
        # Create inventory adjustments for variances
        @cycle_count.create_variance_adjustments!
      end

      redirect_to admin_cycle_count_path(@cycle_count), notice: 'Conteo actualizado exitosamente.'
    else
      render :edit
    end
  end

  private

  def set_cycle_count
    @cycle_count = CycleCount.find(params[:cycle_count_id])
  end

  def set_cycle_count_item
    @cycle_count_item = @cycle_count.cycle_count_items.find(params[:id])
  end

  def cycle_count_item_params
    params.require(:cycle_count_item).permit(:counted_quantity, :notes)
  end
end
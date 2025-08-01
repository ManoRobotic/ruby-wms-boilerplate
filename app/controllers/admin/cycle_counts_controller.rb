class Admin::CycleCountsController < AdminController
  before_action :set_cycle_count, only: [ :show, :edit, :update, :destroy, :start, :complete ]

  def index
    @cycle_counts = CycleCount.includes(:warehouse, :admin, :location, :cycle_count_items)
                             .order(created_at: :desc)
                             .page(params[:page])
                             .per(20)

    @cycle_counts = @cycle_counts.by_status(params[:status]) if params[:status].present?
  end

  def show
    @cycle_count_items = @cycle_count.cycle_count_items.includes(:product)
  end

  def new
    @cycle_count = CycleCount.new
    @warehouses = Warehouse.active
    @locations = Location.active
  end

  def create
    @cycle_count = CycleCount.new(cycle_count_params)
    @cycle_count.admin = current_admin

    if @cycle_count.save
      redirect_to admin_cycle_counts_path, notice: "Conteo cíclico creado exitosamente."
    else
      @warehouses = Warehouse.active
      @locations = Location.active
      render :new
    end
  end

  def edit
    @warehouses = Warehouse.active
    @locations = Location.active
  end

  def update
    if @cycle_count.update(cycle_count_params)
      redirect_to admin_cycle_count_path(@cycle_count), notice: "Conteo cíclico actualizado exitosamente."
    else
      @warehouses = Warehouse.active
      @locations = Location.active
      render :edit
    end
  end

  def destroy
    if @cycle_count.status == "scheduled"
      @cycle_count.destroy
      redirect_to admin_cycle_counts_path, notice: "Conteo cíclico eliminado exitosamente."
    else
      redirect_to admin_cycle_counts_path, alert: "No se puede eliminar un conteo en proceso o completado."
    end
  end

  def start
    if @cycle_count.start!
      redirect_to admin_cycle_count_path(@cycle_count), notice: "Conteo cíclico iniciado exitosamente."
    else
      redirect_to admin_cycle_counts_path, alert: "No se pudo iniciar el conteo cíclico."
    end
  end

  def complete
    if @cycle_count.complete!
      redirect_to admin_cycle_count_path(@cycle_count), notice: "Conteo cíclico completado exitosamente."
    else
      redirect_to admin_cycle_counts_path, alert: "No se pudo completar el conteo cíclico."
    end
  end

  private

  def set_cycle_count
    @cycle_count = CycleCount.find(params[:id])
  end

  def cycle_count_params
    params.require(:cycle_count).permit(:warehouse_id, :location_id, :count_type,
                                       :scheduled_date, :status, :notes)
  end
end

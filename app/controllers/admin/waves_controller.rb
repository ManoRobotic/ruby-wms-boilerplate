class Admin::WavesController < AdminController
  include StandardCrudResponses
  before_action :set_wave, only: [:show, :edit, :update, :destroy, :release, :start, :complete, :cancel]
  before_action :set_warehouse, only: [:index, :new, :create, :auto_create, :suggestions]

  def index
    @waves = @warehouse.waves.includes(:admin, :orders, :pick_lists)
                      .order(created_at: :desc)
                      .page(params[:page])
                      .per(20)

    @waves = @waves.by_status(params[:status]) if params[:status].present?
    @waves = @waves.where(wave_type: params[:wave_type]) if params[:wave_type].present?

    # Statistics for dashboard
    @stats = {
      active_waves: @warehouse.waves.active.count,
      completed_today: @warehouse.waves.completed.where(actual_end_time: Date.current.beginning_of_day..Date.current.end_of_day).count,
      pending_orders: @warehouse.orders.where(wave_id: nil, status: ['pending', 'processing', 'confirmed']).count,
      avg_efficiency: calculate_average_efficiency
    }
  end

  def show
    @metrics = WaveManagementService.new(@wave.warehouse).wave_metrics(@wave)
    @pick_lists = @wave.pick_lists.includes(:admin, :order, :pick_list_items)
  end

  def new
    @wave = @warehouse.waves.build(
      planned_start_time: 1.hour.from_now,
      admin: current_admin
    )
    @available_orders = @warehouse.orders.where(wave_id: nil, status: ['pending', 'processing', 'confirmed'])
                                         .includes(:order_products)
                                         .limit(50)
  end

  def create
    @wave = @warehouse.waves.build(wave_params)
    @wave.admin = current_admin

    respond_to do |format|
      if @wave.save
        # Assign selected orders if provided
        if params[:order_ids].present?
          order_ids = params[:order_ids].reject(&:blank?)
          @warehouse.orders.where(id: order_ids).update_all(wave_id: @wave.id)
          @wave.reload
        end

        format.html { redirect_to admin_warehouse_wave_path(@warehouse, @wave), notice: 'Wave creada exitosamente.' }
        format.json { render :show, status: :created, location: [:admin, @warehouse, @wave] }
      else
        @available_orders = @warehouse.orders.where(wave_id: nil, status: ['pending', 'processing', 'confirmed'])
                                             .includes(:order_products)
                                             .limit(50)
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @wave.errors, status: :unprocessable_entity }
      end
    end
  end

  def auto_create
    service = WaveManagementService.new(@warehouse)
    
    begin
      @wave = service.create_auto_wave(
        strategy: params[:strategy] || 'zone_based',
        wave_type: params[:wave_type] || 'standard',
        priority: params[:priority]&.to_i || 5,
        max_orders: params[:max_orders]&.to_i || 50,
        max_items: params[:max_items]&.to_i || 200,
        planned_start_time: params[:planned_start_time]&.to_datetime || 1.hour.from_now,
        admin: current_admin
      )

      if @wave
        redirect_to admin_warehouse_wave_path(@warehouse, @wave), 
                    notice: "Wave automática creada: #{@wave.name} con #{@wave.total_orders} órdenes."
      else
        redirect_to admin_warehouse_waves_path(@warehouse), 
                    alert: 'No se pudieron encontrar órdenes elegibles para crear una wave.'
      end
    rescue StandardError => e
      Rails.logger.error "Error creating auto wave: #{e.message}"
      redirect_to admin_warehouse_waves_path(@warehouse), 
                  alert: "Error creando wave automática: #{e.message}"
    end
  end

  def suggestions
    service = WaveManagementService.new(@warehouse)
    @suggestions = service.suggest_waves

    respond_to do |format|
      format.html { render :suggestions }
      format.json { render json: @suggestions }
    end
  end

  def edit
    @available_orders = @warehouse.orders.where(wave_id: [nil, @wave.id], status: ['pending', 'processing', 'confirmed'])
                                         .includes(:order_products)
  end

  def update
    respond_to do |format|
      if @wave.update(wave_params)
        # Update order assignments if provided
        if params[:order_ids].present?
          # Remove wave from currently assigned orders
          @wave.orders.update_all(wave_id: nil)
          
          # Assign new orders
          order_ids = params[:order_ids].reject(&:blank?)
          @warehouse.orders.where(id: order_ids).update_all(wave_id: @wave.id)
          @wave.reload
        end

        format.html { redirect_to admin_warehouse_wave_path(@warehouse, @wave), notice: 'Wave actualizada exitosamente.' }
        format.json { render :show, status: :ok, location: [:admin, @warehouse, @wave] }
      else
        @available_orders = @warehouse.orders.where(wave_id: [nil, @wave.id], status: ['pending', 'processing', 'confirmed'])
                                             .includes(:order_products)
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @wave.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @wave.active?
      redirect_to admin_warehouse_waves_path(@warehouse), 
                  alert: 'No se puede eliminar una wave activa. Primero cancélala.'
    else
      @wave.destroy
      redirect_to admin_warehouse_waves_path(@warehouse), 
                  notice: 'Wave eliminada exitosamente.'
    end
  end

  # Wave Actions
  def release
    if @wave.release!
      redirect_to admin_warehouse_wave_path(@warehouse, @wave), 
                  notice: "Wave #{@wave.name} liberada exitosamente. Se generaron #{@wave.pick_lists.count} listas de picking."
    else
      redirect_to admin_warehouse_wave_path(@warehouse, @wave), 
                  alert: 'No se pudo liberar la wave. Verifica que tenga órdenes asignadas y fecha planificada.'
    end
  end

  def start
    if @wave.start!
      WaveNotificationJob.perform_later(@wave, 'started')
      redirect_to admin_warehouse_wave_path(@warehouse, @wave), 
                  notice: "Wave #{@wave.name} iniciada exitosamente."
    else
      redirect_to admin_warehouse_wave_path(@warehouse, @wave), 
                  alert: 'No se pudo iniciar la wave. Verifica que esté liberada.'
    end
  end

  def complete
    if @wave.complete!
      WaveNotificationJob.perform_later(@wave, 'completed')
      redirect_to admin_warehouse_wave_path(@warehouse, @wave), 
                  notice: "Wave #{@wave.name} completada exitosamente."
    else
      redirect_to admin_warehouse_wave_path(@warehouse, @wave), 
                  alert: 'No se pudo completar la wave. Verifica que todas las listas de picking estén completadas.'
    end
  end

  def cancel
    if @wave.cancel!
      redirect_to admin_warehouse_wave_path(@warehouse, @wave), 
                  notice: "Wave #{@wave.name} cancelada exitosamente."
    else
      redirect_to admin_warehouse_wave_path(@warehouse, @wave), 
                  alert: 'No se pudo cancelar la wave.'
    end
  end

  private

  def set_wave
    @wave = Wave.find(params[:id])
    @warehouse = @wave.warehouse
  end

  def set_warehouse
    @warehouse = Warehouse.find(params[:warehouse_id])
  end

  def wave_params
    params.require(:wave).permit(:name, :wave_type, :strategy, :priority, :planned_start_time, :notes)
  end

  def calculate_average_efficiency
    completed_waves = @warehouse.waves.completed.where(actual_end_time: 30.days.ago..Time.current)
    return 0 if completed_waves.empty?

    total_efficiency = completed_waves.sum do |wave|
      wave.efficiency_score || 0
    end

    (total_efficiency.to_f / completed_waves.count).round(1)
  end
end
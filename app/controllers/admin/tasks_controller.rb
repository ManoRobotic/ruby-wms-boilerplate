class Admin::TasksController < AdminController
  before_action :set_task, only: [ :show, :edit, :update, :destroy, :assign, :start, :complete, :cancel ]
  before_action :authorize_task_management!, except: [ :index, :show ]
  before_action :authorize_task_read!, only: [ :index, :show ]
  before_action :check_task_warehouse_access!, only: [ :show, :edit, :update, :destroy, :assign, :start, :complete, :cancel ]

  def index
    @tasks = Task.includes(:warehouse, :location, :product)

    # Filter by user's warehouse if not admin
    if current_user && current_user.warehouse_id.present?
      @tasks = @tasks.by_warehouse(current_user.warehouse_id)
    end

    # Additional filters
    @tasks = @tasks.by_warehouse(params[:warehouse_id]) if params[:warehouse_id].present? && current_admin
    @tasks = @tasks.by_type(params[:task_type]) if params[:task_type].present?
    @tasks = @tasks.by_status(params[:status]) if params[:status].present?
    @tasks = @tasks.by_priority(params[:priority]) if params[:priority].present?
    @tasks = @tasks.by_admin(params[:admin_id]) if params[:admin_id].present?

    # Default ordering by priority and creation date
    @tasks = @tasks.by_priority_order.recent
                   .page(params[:page])
                   .per(25)

    @task_stats = {
      pending: Task.pending.count,
      in_progress: Task.in_progress.count,
      completed_today: Task.completed.where(completed_at: Date.current.beginning_of_day..Date.current.end_of_day).count,
      overdue: Task.overdue.count
    }
  end

  def show
    @duration = @task.duration
    @related_transactions = @task.inventory_transactions if @task.completed?
  end

  def new
    @task = Task.new
    @warehouses = Warehouse.active
    @products = Product.active
  end

  def create
    @task = Task.new(task_params)
    @task.admin_id = current_admin.id

    if @task.save
      redirect_to admin_task_path(@task), notice: "Task was successfully created."
    else
      @warehouses = Warehouse.active
      @products = Product.active
      render :new
    end
  end

  def edit
    @warehouses = Warehouse.active
    @products = Product.active
  end

  def update
    if @task.update(task_params)
      redirect_to admin_task_path(@task), notice: "Task was successfully updated."
    else
      @warehouses = Warehouse.active
      @products = Product.active
      render :edit
    end
  end

  def destroy
    if @task.pending? || @task.cancelled?
      @task.destroy
      redirect_to admin_tasks_path, notice: "Tarea eliminada exitosamente."
    else
      redirect_to admin_tasks_path, alert: "Solo se pueden eliminar tareas pendientes o canceladas."
    end
  end

  # WMS Actions
  def assign
    Rails.logger.info "=== ASSIGN ACTION CALLED ==="
    Rails.logger.info "Task ID: #{params[:id]}"
    Rails.logger.info "User ID: #{params[:user_id]}"
    Rails.logger.info "All params: #{params.inspect}"

    # If user_id is provided, assign to that user, otherwise assign to current admin
    if params[:user_id].present?
      Rails.logger.info "Finding user with ID: #{params[:user_id]}"
      user = User.find(params[:user_id])
      Rails.logger.info "Found user: #{user.display_name} (#{user.email})"

      Rails.logger.info "Attempting to assign task #{@task.id} to user #{user.id}"
      if @task.assign_to_user!(user)
        Rails.logger.info "Task assigned successfully"
        respond_to do |format|
          format.html { redirect_to admin_tasks_path, notice: "Tarea asignada exitosamente a #{user.display_name}." }
          format.json { render json: { success: true, message: "Tarea asignada exitosamente a #{user.display_name}." } }
        end
      else
        Rails.logger.error "Failed to assign task to user"
        respond_to do |format|
          format.html { redirect_to admin_tasks_path, alert: "No se pudo asignar la tarea al usuario." }
          format.json { render json: { success: false, message: "No se pudo asignar la tarea al usuario." }, status: 422 }
        end
      end
    else
      Rails.logger.info "No user_id provided, assigning to current admin"
      if @task.assign_to!(current_admin)
        respond_to do |format|
          format.html { redirect_to admin_task_path(@task), notice: "Tarea asignada exitosamente." }
          format.json { render json: { success: true, message: "Tarea asignada exitosamente." } }
        end
      else
        respond_to do |format|
          format.html { redirect_to admin_task_path(@task), alert: "No se pudo asignar la tarea." }
          format.json { render json: { success: false, message: "No se pudo asignar la tarea." }, status: 422 }
        end
      end
    end
  end

  def start
    if @task.start!
      redirect_to admin_task_path(@task), notice: "Task started successfully."
    else
      redirect_to admin_task_path(@task), alert: "Could not start task."
    end
  end

  def complete
    notes = params[:completion_notes]
    if @task.complete!(notes)
      redirect_to admin_task_path(@task), notice: "Task completed successfully."
    else
      redirect_to admin_task_path(@task), alert: "Could not complete task."
    end
  end

  def cancel
    reason = params[:cancellation_reason]
    if @task.cancel!(reason)
      redirect_to admin_task_path(@task), notice: "Task cancelled successfully."
    else
      redirect_to admin_task_path(@task), alert: "Could not cancel task."
    end
  end

  # Bulk actions
  def bulk_assign
    task_ids = params[:task_ids]
    admin_id = params[:admin_id]

    if task_ids.present? && admin_id.present?
      admin = Admin.find(admin_id)
      tasks = Task.where(id: task_ids, status: "pending")

      count = 0
      tasks.each do |task|
        if task.assign_to!(admin)
          count += 1
        end
      end

      redirect_to admin_tasks_path, notice: "#{count} tasks assigned successfully."
    else
      redirect_to admin_tasks_path, alert: "Please select tasks and admin to assign."
    end
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:task_type, :priority, :warehouse_id, :location_id,
                                :product_id, :quantity, :instructions, :from_location_id,
                                :to_location_id)
  end

  def authorize_task_management!
    unless current_admin || current_user&.can?("create_tasks")
      redirect_to admin_root_path, alert: "No tienes permisos para gestionar tareas."
    end
  end

  def authorize_task_read!
    unless current_admin || current_user&.can?("read_tasks")
      redirect_to admin_root_path, alert: "No tienes permisos para ver tareas."
    end
  end

  def check_task_warehouse_access!
    if current_user && current_user.warehouse_id.present?
      unless @task.warehouse_id == current_user.warehouse_id
        redirect_to admin_tasks_path, alert: "No tienes acceso a tareas de este almacén."
      end
    end
  end
end

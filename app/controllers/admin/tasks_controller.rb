class Admin::TasksController < AdminController
  before_action :set_task, only: [:show, :edit, :update, :destroy, :assign, :start, :complete, :cancel]
  
  def index
    @tasks = Task.includes(:warehouse, :location, :product, :admin)
    
    # Filters
    @tasks = @tasks.by_warehouse(params[:warehouse_id]) if params[:warehouse_id].present?
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
    @task.admin = current_admin
    
    if @task.save
      redirect_to admin_task_path(@task), notice: 'Task was successfully created.'
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
      redirect_to admin_task_path(@task), notice: 'Task was successfully updated.'
    else
      @warehouses = Warehouse.active
      @products = Product.active
      render :edit
    end
  end

  def destroy
    if @task.pending?
      @task.destroy
      redirect_to admin_tasks_path, notice: 'Task was successfully deleted.'
    else
      redirect_to admin_task_path(@task), alert: 'Cannot delete task that is not pending.'
    end
  end
  
  # WMS Actions
  def assign
    if @task.assign_to!(current_admin)
      redirect_to admin_task_path(@task), notice: 'Task assigned successfully.'
    else
      redirect_to admin_task_path(@task), alert: 'Could not assign task.'
    end
  end
  
  def start
    if @task.start!
      redirect_to admin_task_path(@task), notice: 'Task started successfully.'
    else
      redirect_to admin_task_path(@task), alert: 'Could not start task.'
    end
  end
  
  def complete
    notes = params[:completion_notes]
    if @task.complete!(notes)
      redirect_to admin_task_path(@task), notice: 'Task completed successfully.'
    else
      redirect_to admin_task_path(@task), alert: 'Could not complete task.'
    end
  end
  
  def cancel
    reason = params[:cancellation_reason]
    if @task.cancel!(reason)
      redirect_to admin_task_path(@task), notice: 'Task cancelled successfully.'
    else
      redirect_to admin_task_path(@task), alert: 'Could not cancel task.'
    end
  end
  
  # Bulk actions
  def bulk_assign
    task_ids = params[:task_ids]
    admin_id = params[:admin_id]
    
    if task_ids.present? && admin_id.present?
      admin = Admin.find(admin_id)
      tasks = Task.where(id: task_ids, status: 'pending')
      
      count = 0
      tasks.each do |task|
        if task.assign_to!(admin)
          count += 1
        end
      end
      
      redirect_to admin_tasks_path, notice: "#{count} tasks assigned successfully."
    else
      redirect_to admin_tasks_path, alert: 'Please select tasks and admin to assign.'
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
end
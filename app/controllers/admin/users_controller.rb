class Admin::UsersController < AdminController
  include StandardCrudResponses
  before_action :set_user, only: [ :show, :edit, :update, :destroy, :activate, :deactivate ]
  # before_action :authorize_user_management!

  # Temporary skip authorization for creating first admin user
  skip_before_action :verify_authenticity_token, only: [ :create ]

  def index
    @users = User.includes(:warehouse)
                 .order(created_at: :desc)
                 .page(params[:page])
                 .per(20)

    @users = @users.by_role(params[:role]) if params[:role].present?
    @users = @users.by_warehouse(params[:warehouse_id]) if params[:warehouse_id].present?
    @users = @users.where(active: params[:active] == "true") if params[:active].present?

    # Statistics
    @stats = {
      total_users: User.count,
      active_users: User.active.count,
      admins: User.admins.count,
      supervisors: User.supervisors.count,
      pickers: User.pickers.count,
      regular_users: User.users.count
    }

    @warehouses = Warehouse.active.order(:name)
  end

  def show
    # User metrics and activity
    @user_stats = {
      tasks_completed: @user.tasks.completed.count,
      pick_lists_completed: @user.pick_lists.completed.count,
      inventory_transactions: @user.inventory_transactions.count,
      created_at: @user.created_at,
      updated_at: @user.updated_at
    }
  end

  def new
    @user = User.new
    @warehouses = Warehouse.active.order(:name)
  end

  def create
    @user = User.new(user_params)
    @user.password = generate_temp_password
    @user.password_confirmation = @user.password

    respond_to do |format|
      if @user.save
        # Enviar email con contraseña temporal (opcional)
        # UserMailer.welcome_email(@user, @user.password).deliver_later

        format.html { redirect_to admin_users_path, notice: "Usuario creado exitosamente. Contraseña temporal: #{@user.password}" }
        format.json { render :show, status: :created, location: [ :admin, @user ] }
      else
        @warehouses = Warehouse.active.order(:name)
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @warehouses = Warehouse.active.order(:name)
  end

  def update
    # No actualizar password si no se proporciona
    if user_params[:password].blank?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end

    respond_to do |format|
      if @user.update(user_params.except(:password, :password_confirmation).merge(password_params))
        format.html { redirect_to admin_users_path, notice: "Usuario actualizado exitosamente." }
        format.json { render :show, status: :ok, location: [ :admin, @user ] }
      else
        @warehouses = Warehouse.active.order(:name)
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @user.admin? && User.admins.count <= 1
      redirect_to admin_users_path, alert: "No se puede eliminar el último administrador."
      return
    end

    @user.destroy
    redirect_to admin_users_path, notice: "Usuario eliminado exitosamente."
  end

  def activate
    @user.update!(active: true)
    redirect_to admin_users_path, notice: "Usuario activado exitosamente."
  end

  def deactivate
    if @user.admin? && User.admins.active.count <= 1
      redirect_to admin_users_path, alert: "No se puede desactivar el último administrador activo."
      return
    end

    @user.update!(active: false)
    redirect_to admin_users_path, notice: "Usuario desactivado exitosamente."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    permitted = [ :name, :email, :role, :warehouse_id, :active ]
    permitted += [ :password, :password_confirmation ] if params[:user][:password].present?
    user_params = params.require(:user).permit(permitted)

    # Convert empty warehouse_id to nil for admins
    if user_params[:role] == "admin" && user_params[:warehouse_id].blank?
      user_params[:warehouse_id] = nil
    end

    user_params
  end

  def password_params
    if params[:user][:password].present?
      {
        password: params[:user][:password],
        password_confirmation: params[:user][:password_confirmation]
      }
    else
      {}
    end
  end

  def generate_temp_password
    # SecureRandom.hex(4) # 8 character password
    "abcd1234" # Default password
  end

  def authorize_user_management!
    unless current_admin || current_user&.can?("manage_users")
      redirect_to admin_root_path, alert: "No tienes permisos para gestionar usuarios."
    end
  end
end

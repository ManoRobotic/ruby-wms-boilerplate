class Admin::UsersController < AdminController
  include StandardCrudResponses
  before_action :set_user, only: [ :show, :edit, :update, :destroy, :activate, :deactivate ]
  # before_action :authorize_user_management!

  # Temporary skip authorization for creating first admin user
  skip_before_action :verify_authenticity_token, only: [ :create ]

  def index
    @users = User.includes(:warehouse)

    if current_admin.present?
      if current_admin.super_admin?
        # Super admin sees all users (no additional filtering needed here)
      elsif current_admin.company_id.present?
        # Regular admin sees users from their company
        @users = @users.where(company_id: current_admin.company_id)
      else
        # Admin without a company_id
        # They might see only users they created, or no users.
        # For now, let's assume they see no users if not explicitly tied to a company.
        @users = User.none
      end
    else
      # No admin logged in, or unauthorized access (should be caught by before_action)
      @users = User.none
    end

    @users = @users.order(created_at: :desc)
                 .page(params[:page])
                 .per(20)

    # Statistics
    @stats = {
      total_users: @users.count,
      active_users: @users.active.count,
      admins: @users.admins.count,
      supervisors: @users.supervisors.count,
      pickers: @users.pickers.count,
      regular_users: @users.users.count,
      operadores: @users.operadores.count # Add operadores count
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

    # Assign company_id if current_admin is present and has one
    if current_admin.present? && current_admin.company_id.present?
      @user.company_id = current_admin.company_id
    end

    # Assign super_admin_role if current_admin is present and has one
    if current_admin.present? && current_admin.super_admin_role.present?
      @user.super_admin_role = current_admin.super_admin_role
    end

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
    permitted = [ :name, :email, :role, :warehouse_id, :active, :super_admin_role ]
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
    "password123" # Default password
  end

  def authorize_user_management!
    unless current_admin || current_user&.can?("manage_users")
      redirect_to admin_root_path, alert: "No tienes permisos para gestionar usuarios."
    end
  end
end

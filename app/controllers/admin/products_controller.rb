class Admin::ProductsController < AdminController
  before_action :set_admin_product, only: %i[ show edit update destroy ]

  # GET /admin/products or /admin/products.json
  def index
    @admin_products = @product_scope.with_attached_images.includes(:category, :stocks).all.page(params[:page]).per(20)
  end

  # GET /admin/products/1 or /admin/products/1.json
  def show
  end

  # GET /admin/products/new
  def new
    @admin_product = @product_scope.new
  end

  # GET /admin/products/1/edit
  def edit
  end

  # POST /admin/products or /admin/products.json
  def create
    @admin_product = @product_scope.new(admin_product_params)

    respond_to do |format|
      if @admin_product.save
        format.html { redirect_to admin_products_path(@admin_product), notice: t("admin.products.created") }
        format.json { render :show, status: :created, location: @admin_product }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @admin_product.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/products/1 or /admin/products/1.json
  def update
    respond_to do |format|
      if @admin_product.update(admin_product_params.except(:images))
        # Handle image attachments if present
        if admin_product_params[:images]
          admin_product_params[:images].each do |image|
            @admin_product.images.attach(image)
          end
        end

        format.html { redirect_to admin_products_path(@admin_product), notice: t("admin.products.updated") }
        format.json { render :show, status: :ok, location: admin_product_path(@admin_product) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @admin_product.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/products/1 or /admin/products/1.json
  def destroy
    @admin_product.destroy!

    respond_to do |format|
      format.html { redirect_to admin_products_path(@admin_product), status: :see_other, notice: t("admin.products.deleted") }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_admin_product
      @admin_product = @product_scope.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def admin_product_params
      params.require(:product).permit(:name, :description, :price, :category_id, :active, :image_url, :company_id, images: [])
    end
end

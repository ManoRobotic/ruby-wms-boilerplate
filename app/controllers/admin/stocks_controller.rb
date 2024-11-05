class Admin::StocksController < AdminController
  before_action :set_stock, only: %i[ show edit update destroy ]

  # GET /admin/stocks or /admin/stocks.json
  def index
    @admin_stocks = Stock.all
  end

  # GET /admin/stocks/1 or /admin/stocks/1.json
  def show
  end

  # GET /admin/stocks/new
  def new
    @admin_stock = Stock.new
  end

  # GET /admin/stocks/1/edit
  def edit
  end

  # POST /admin/stocks or /admin/stocks.json
  def create
    @admin_stock = Stock.new(stock_params)

    respond_to do |format|
      if @admin_stock.save
        format.html { redirect_to @admin_stock, notice: "Stock was successfully created." }
        format.json { render :show, status: :created, location: @admin_stock }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @admin_stock.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/stocks/1 or /admin/stocks/1.json
  def update
    respond_to do |format|
      if @admin_stock.update(stock_params)
        format.html { redirect_to @admin_stock, notice: "Stock was successfully updated." }
        format.json { render :show, status: :ok, location: @admin_stock }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @admin_stock.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/stocks/1 or /admin/stocks/1.json
  def destroy
    @admin_stock.destroy!

    respond_to do |format|
      format.html { redirect_to admin_stocks_path, status: :see_other, notice: "Stock was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_stock
      @admin_stock = Stock.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def stock_params
      params.require(:stock).permit(:product_id, :amount, :size)
    end
end

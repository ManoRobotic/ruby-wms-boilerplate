class Admin::LocationsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_warehouse_and_zone
  before_action :set_location, only: [ :show, :edit, :update, :destroy ]

  def index
    @locations = @zone.locations.includes(:stocks)
                     .page(params[:page])
                     .per(50)

    @locations = @locations.by_type(params[:location_type]) if params[:location_type].present?
    @locations = @locations.search(params[:search]) if params[:search].present?
    @locations = @locations.available if params[:available] == "true"
    @locations = @locations.with_stock if params[:with_stock] == "true"
  end

  def show
    @current_products = @location.current_products
    @recent_transactions = @location.inventory_transactions.recent.limit(10)
    @pending_tasks = @location.pending_tasks
  end

  def new
    @location = @zone.locations.build
  end

  def create
    @location = @zone.locations.build(location_params)

    if @location.save
      redirect_to admin_warehouse_zone_location_path(@warehouse, @zone, @location),
                  notice: "Location was successfully created."
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @location.update(location_params)
      redirect_to admin_warehouse_zone_location_path(@warehouse, @zone, @location),
                  notice: "Location was successfully updated."
    else
      render :edit
    end
  end

  def destroy
    if @location.stocks.any?
      redirect_to admin_warehouse_zone_locations_path(@warehouse, @zone),
                  alert: "Cannot delete location with existing stock."
    else
      @location.destroy
      redirect_to admin_warehouse_zone_locations_path(@warehouse, @zone),
                  notice: "Location was successfully deleted."
    end
  end

  # WMS specific actions
  def cycle_count
    @cycle_count = @location.cycle_counts.build
  end

  def create_cycle_count
    @cycle_count = @location.cycle_counts.build(cycle_count_params)
    @cycle_count.warehouse = @warehouse
    @cycle_count.admin = current_admin

    if @cycle_count.save
      redirect_to admin_warehouse_zone_location_path(@warehouse, @zone, @location),
                  notice: "Cycle count scheduled successfully."
    else
      render :cycle_count
    end
  end

  private

  def set_warehouse_and_zone
    @warehouse = Warehouse.find(params[:warehouse_id])
    @zone = @warehouse.zones.find(params[:zone_id])
  end

  def set_location
    @location = @zone.locations.find(params[:id])
  end

  def location_params
    params.require(:location).permit(:aisle, :bay, :level, :position, :barcode,
                                   :location_type, :capacity, :active)
  end

  def cycle_count_params
    params.require(:cycle_count).permit(:count_type, :scheduled_date, :notes)
  end
end

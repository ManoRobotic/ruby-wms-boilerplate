class Admin::ZonesController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_warehouse
  before_action :set_zone, only: [ :show, :edit, :update, :destroy ]

  def index
    @zones = @warehouse.zones.includes(:locations)
                      .page(params[:page])
                      .per(20)

    @zones = @zones.by_type(params[:zone_type]) if params[:zone_type].present?
    @zones = @zones.search(params[:search]) if params[:search].present?
  end

  def show
    @locations_count = @zone.locations.count
    @utilization = @zone.utilization_percentage
    @available_locations = @zone.available_locations.count
  end

  def new
    @zone = @warehouse.zones.build
  end

  def create
    @zone = @warehouse.zones.build(zone_params)

    if @zone.save
      redirect_to admin_warehouse_zone_path(@warehouse, @zone), notice: "Zone was successfully created."
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @zone.update(zone_params)
      redirect_to admin_warehouse_zone_path(@warehouse, @zone), notice: "Zone was successfully updated."
    else
      render :edit
    end
  end

  def destroy
    if @zone.locations.any?
      redirect_to admin_warehouse_zones_path(@warehouse), alert: "Cannot delete zone with existing locations."
    else
      @zone.destroy
      redirect_to admin_warehouse_zones_path(@warehouse), notice: "Zone was successfully deleted."
    end
  end

  private

  def set_warehouse
    @warehouse = Warehouse.find(params[:warehouse_id])
  end

  def set_zone
    @zone = @warehouse.zones.find(params[:id])
  end

  def zone_params
    params.require(:zone).permit(:name, :code, :zone_type, :description)
  end
end

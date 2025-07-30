class PickListOptimizationJob < ApplicationJob
  queue_as :default

  def perform(pick_list_id)
    pick_list = PickList.find(pick_list_id)

    Rails.logger.info "Optimizing pick list: #{pick_list.pick_list_number}"

    # Optimize the route
    PickListService.new.optimize_pick_route(pick_list: pick_list)

    # Update estimated completion time
    update_estimated_completion_time(pick_list)

    Rails.logger.info "Pick list optimization completed: #{pick_list.pick_list_number}"
  end

  private

  def update_estimated_completion_time(pick_list)
    # Calculate estimated time based on:
    # - Number of items
    # - Number of locations
    # - Distance between locations
    # - Historical performance

    base_time = 5.minutes # Base setup time
    time_per_item = 2.minutes # Average time per item
    travel_time = calculate_travel_time(pick_list)

    estimated_time = base_time + (pick_list.total_items * time_per_item) + travel_time

    # Store in a custom field or cache if needed
    Rails.cache.write("pick_list_#{pick_list.id}_estimated_time", estimated_time.to_i, expires_in: 1.hour)
  end

  def calculate_travel_time(pick_list)
    # Simple calculation based on number of unique locations
    unique_locations = pick_list.pick_list_items.joins(:location).distinct.count(:location_id)

    # Assume 1 minute travel time between locations
    (unique_locations - 1) * 1.minute
  end
end

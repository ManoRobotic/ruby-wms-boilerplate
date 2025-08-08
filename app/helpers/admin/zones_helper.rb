# app/helpers/admin/zones_helper.rb
module Admin::ZonesHelper
  def zone_type_badge_color(zone_type)
    case zone_type.downcase
    when "receiving" then "bg-blue-100 text-blue-800"
    when "storage" then "bg-green-100 text-green-800"
    when "shipping" then "bg-purple-100 text-purple-800"
    when "quarantine" then "bg-red-100 text-red-800"
    else "bg-gray-100 text-gray-800"
    end
  end
end

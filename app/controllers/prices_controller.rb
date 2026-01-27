class PricesController < ApplicationController
    def index
        @precios = Rails.cache.fetch("bbva_prices", expires_in: 1.hour) do
            fetch_prices_safely
        end

        respond_to do |format|
            format.html
            format.json { render json: { prices: @precios, cached_at: Time.current.iso8601 } }
        end
    end

    private

    def fetch_prices_safely
        # Placeholder implementation since BbvaScraper service doesn't exist
        # In a real implementation, you would fetch from an actual API
        get_mock_prices
    rescue StandardError => e
        Rails.logger.error "Failed to fetch prices: #{e.message}"
        # Return cached data if available, or empty hash
        Rails.cache.fetch("bbva_prices_fallback", expires_in: 1.day) { {} }
    end

    def get_mock_prices
        # Mock data for demonstration purposes
        {
            "Oro" => { "compra" => "1500.00", "venta" => "1520.00" },
            "Plata" => { "compra" => "25.50", "venta" => "26.00" }
        }
    end
end

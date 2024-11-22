class PricesController < ApplicationController
    def index
        @precios = BbvaScraper.obtener_precios
    end
end

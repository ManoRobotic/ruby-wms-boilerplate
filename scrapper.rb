require 'httparty'
require 'nokogiri'

url = 'https://bbv.infosel.com/bancomerindicators/indexV9.aspx'
response = HTTParty.get(url)

if response.code == 200
  doc = Nokogiri::HTML(response.body)

  onza_libertad = doc.at_css("a[href*='OroLibertadClosesCV.html']")&.ancestors('div.col-sm-4')

  if onza_libertad
    compra = onza_libertad.at_css("div.d-flex > div.border-right .precio-c")&.text&.strip
    venta = onza_libertad.at_css("div.d-flex > div:not(.border-right) .precio-c")&.text&.strip

    puts "Compra: #{compra}" if compra
    puts "Venta: #{venta}" if venta
    puts "No se pudo encontrar la información de precios en el contenedor." unless compra && venta
  else
    puts "No se encontró el contenedor de Onza Libertad de Oro en la página."
  end
else
  puts "Error al obtener la página: #{response.code}"
end

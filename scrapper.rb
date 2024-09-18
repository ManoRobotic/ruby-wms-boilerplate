require 'httparty'
require 'nokogiri'

url = 'https://bbv.infosel.com/bancomerindicators/indexV9.aspx'
response = HTTParty.get(url)

if response.code == 200
  doc = Nokogiri::HTML(response.body)

  onza_oro_libertad = doc.at_css("a[href*='OroLibertadClosesCV.html']")&.ancestors('div.col-sm-4')
  onza_plata_libertad = doc.at_css("a[href*='PlataLibertadClosesCV.html']")&.ancestors('div.col-sm-4')

  if onza_oro_libertad
    compra_oro = onza_oro_libertad.at_css("div.d-flex > div.border-right .precio-c")&.text&.strip
    venta_oro = onza_oro_libertad.at_css("div.d-flex > div:not(.border-right) .precio-c")&.text&.strip

    puts "Oro - Compra: #{compra_oro}" if compra_oro
    puts "Oro - Venta: #{venta_oro}" if venta_oro
    puts "Oro - No se pudo encontrar la información de precios en el contenedor." unless compra_oro && venta_oro
  else
    puts "Oro - No se encontró la data de la Onza Libertad de Oro en la página de bbva."
  end

  if onza_plata_libertad
    compra_plata = onza_plata_libertad.at_css("div.d-flex > div.border-right .precio-c")&.text&.strip
    venta_plata = onza_plata_libertad.at_css("div.d-flex > div:not(.border-right) .precio-c")&.text&.strip

    puts "Plata - Compra: #{compra_plata}" if compra_plata
    puts "Plata - Venta: #{venta_plata}" if venta_plata
    puts "Plata - No se pudo encontrar la información de precios en el contenedor." unless compra_plata && venta_plata
  else
    puts "Plata - No se encontró la data de la Onza Libertad de Plata en la páginan de bbva."
  end
else
  puts "Error al obtener la página: #{response.code}"
end

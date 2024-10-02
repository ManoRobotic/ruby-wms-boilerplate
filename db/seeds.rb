Category.destroy_all
r
Category.create(name: "Oro", description: "Monedas de Oro", image: "https://www.banxico.org.mx/multimedia/libertadOroFrente.png")
Category.create(name: "Plata", description: "Monedas de Plata", image: "https://www.banxico.org.mx/multimedia/NvaSerLibPlaRev.png")
Category.create(name: "Numismática", description: "Monedas Numismática", image: "https://www.banxico.org.mx/ColeccionNumismatica/resources/images/bienvenida/imgs_menu_monedas.png")

puts "Finished seeding Categories"
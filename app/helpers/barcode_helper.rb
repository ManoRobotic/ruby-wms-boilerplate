module BarcodeHelper
  def generate_barcode_image(data, options = {})
    require "base64" unless defined?(Base64)

    # Create barcode
    barcode = Barby::Code128B.new(data)

    # Default options for barcode appearance
    default_options = {
      margin: 0,
      height: 100,
      xdim: 2  # bar width in pixels
    }

    options = default_options.merge(options)

    # Generate PNG
    png_data = barcode.to_png(options)

    # Convert to base64 for embedding in HTML
    base64_png = Base64.strict_encode64(png_data)

    "data:image/png;base64,#{base64_png}"
  end

  def vertical_barcode_image(data, options = {})
    # Create barcode with vertical orientation options
    vertical_options = {
      margin: 0,
      height: 500,  # Tall barcode for vertical placement
      xdim: 1       # Narrower bars for vertical space
    }

    generate_barcode_image(data, vertical_options.merge(options))
  end
end

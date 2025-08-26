class SmartGoogleSheetsService
  def initialize(admin)
    @admin = admin
    @session = GoogleDrive::Session.from_service_account_key(StringIO.new(@admin.google_credentials))
    @spreadsheet = @session.spreadsheet_by_key(@admin.sheet_id)
  end

  def find_opro_worksheet
    # Buscar la hoja que contenga datos de OPRO
    @spreadsheet.worksheets.each do |ws|
      headers = ws.rows[0] if ws.rows.any?
      
      # Si encuentra encabezados como "no_opro", "fec_opro", etc.
      if headers && has_opro_headers?(headers)
        return ws
      end
    end
    
    # Si no encuentra, usar la primera hoja
    @spreadsheet.worksheets.first
  end

  private

  def has_opro_headers?(headers)
    opro_indicators = ['no_opro', 'fec_opro', 'stat_opro', 'clave producto']
    headers.any? { |header| opro_indicators.include?(header.downcase) }
  end
end
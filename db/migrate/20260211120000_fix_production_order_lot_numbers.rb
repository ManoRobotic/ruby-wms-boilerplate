class FixProductionOrderLotNumbers < ActiveRecord::Migration[8.0]
  def up
    # Find all production orders with incorrectly formatted lot numbers
    # These would be ones that don't match the pattern FE-CR-DDMMAAYYNNNN
    ProductionOrder.find_each do |po|
      # Check if the current lote_referencia doesn't match the expected pattern
      if !po.lote_referencia.match?(/^FE-CR-\d{10}$/)
        # Update the lote_referencia using the model's method
        # We need to update the record directly to bypass any potential issues
        date_source = po.fecha_completa || po.created_at || Date.current
        date_part = "FE-CR-#{date_source.strftime('%d%m%y')}"
        
        # Extract the order number from no_opro or use order_number
        order_num = po.no_opro || po.order_number
        # Ensure it's in the right format (4 digits)
        order_suffix = order_num.to_s.gsub(/\D/, '').rjust(4, '0')[-4, 4] || '0000'
        
        correct_lote = "#{date_part}#{order_suffix}"
        
        # Update the record directly in the database
        po.update_column(:lote_referencia, correct_lote)
        
        puts "Fixed lot number for order #{po.no_opro || po.order_number}: #{correct_lote}"
      end
    end
  end

  def down
    # This is a one-way migration to fix data, no rollback needed
    puts "Rollback of lot number fixes not implemented"
  end
end
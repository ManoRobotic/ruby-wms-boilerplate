namespace :inventory do
  desc "Import inventory codes from DBF file"
  task import_codes: :environment do
    require 'dbf'

    # Path to the DBF file
    dbf_file_path = Rails.root.join('dbf', 'ordprod.dbf')
    
    unless File.exist?(dbf_file_path)
      puts "❌ Error: DBF file not found at #{dbf_file_path}"
      puts "Please ensure the file exists and try again."
      exit 1
    end

    puts "🔄 Starting inventory codes import from #{dbf_file_path}"
    
    # Open the DBF file
    begin
      table = DBF::Table.new(dbf_file_path)
      
      puts "📊 Found #{table.record_count} records in the DBF file"
      
      # Counter for imported records
      imported_count = 0
      skipped_count = 0
      error_count = 0
      
      # Process each record
      table.each_with_index do |record, index|
        begin
          # Show progress every 100 records
          if (index + 1) % 100 == 0
            puts "🔄 Processed #{index + 1}/#{table.record_count} records..."
          end
          
          # Extract data from the record
          # Convert numeric fields to appropriate types and handle string fields
          no_ordp_value = record.attributes['no_ordp']
          no_ordp_string = no_ordp_value.is_a?(Numeric) ? no_ordp_value.to_s : no_ordp_value.to_s.strip
          
          attributes = {
            no_ordp: no_ordp_string,
            cve_copr: record.attributes['cve_copr']&.to_s&.strip,
            cve_prod: record.attributes['cve_prod']&.to_s&.strip,
            can_copr: record.attributes['can_copr'],
            tip_copr: record.attributes['tip_copr'],
            costo: record.attributes['costo'],
            fech_cto: record.attributes['fech_cto'],
            cve_suc: record.attributes['cve_suc']&.to_s&.strip,
            trans: record.attributes['trans'],
            lote: record.attributes['lote']&.to_s&.strip,
            new_med: record.attributes['new_med']&.to_s&.strip,
            new_copr: record.attributes['new_copr']&.to_s&.strip,
            costo_rep: record.attributes['costo_rep'],
            partresp: record.attributes['partresp'],
            dmov: record.attributes['dmov']&.to_s&.strip,
            partop: record.attributes['partop'],
            fcdres: record.attributes['fcdres'],
            undres: record.attributes['undres']&.to_s&.strip
          }
          
          # Validate required fields
          if attributes[:no_ordp].blank?
            puts "⚠️  Skipping record #{index + 1} with empty no_ordp"
            skipped_count += 1
            next
          end
          
          # Create or update the inventory code
          inventory_code = InventoryCode.find_or_initialize_by(no_ordp: attributes[:no_ordp])
          
          # Only update if attributes have changed
          if inventory_code.new_record? || inventory_code.attributes.slice(*attributes.keys.map(&:to_s)).values != attributes.values
            inventory_code.assign_attributes(attributes)
            
            if inventory_code.save
              if inventory_code.previous_changes.any?
                # puts "✅ Updated inventory code: #{inventory_code.no_ordp}"
              else
                # puts "➕ Created new inventory code: #{inventory_code.no_ordp}"
              end
              imported_count += 1
            else
              puts "❌ Failed to save inventory code #{attributes[:no_ordp]}: #{inventory_code.errors.full_messages.join(', ')}"
              error_count += 1
            end
          else
            # No changes needed
            skipped_count += 1
          end
          
        rescue => e
          puts "❌ Error processing record #{index + 1}: #{e.message}"
          error_count += 1
        end
      end
      
      # Summary
      puts "\n📈 Import Summary:"
      puts "   ✅ Successfully imported/updated: #{imported_count}"
      puts "   ⏭️  Skipped (no changes needed): #{skipped_count}"
      puts "   ❌ Errors: #{error_count}"
      puts "   📊 Total processed: #{imported_count + skipped_count + error_count}"
      
      if error_count == 0
        puts "\n✅ Import completed successfully!"
      else
        puts "\n⚠️  Import completed with #{error_count} errors."
      end
      
    rescue => e
      puts "❌ Error opening DBF file: #{e.message}"
      puts e.backtrace
      exit 1
    end
  end
  
  desc "Import visible data from DBF file (simplified version for testing)"
  task import_visible_data: :environment do
    # This is a simplified version that mimics the functionality
    # of the import process for testing purposes
    
    puts "🔄 Starting simplified import process..."
    
    # Simulate importing some sample data
    sample_data = [
      { no_ordp: "OP001", cve_copr: "CP001", cve_prod: "PROD001", can_copr: 100.0, tip_copr: 1 },
      { no_ordp: "OP002", cve_copr: "CP002", cve_prod: "PROD002", can_copr: 200.0, tip_copr: 1 },
      { no_ordp: "OP003", cve_copr: "CP003", cve_prod: "PROD003", can_copr: 150.0, tip_copr: 0 }
    ]
    
    imported_count = 0
    
    sample_data.each do |data|
      inventory_code = InventoryCode.find_or_initialize_by(no_ordp: data[:no_ordp])
      inventory_code.assign_attributes(data)
      
      if inventory_code.save
        imported_count += 1
        puts "✅ Imported/Updated: #{inventory_code.no_ordp}"
      else
        puts "❌ Failed to import: #{data[:no_ordp]} - #{inventory_code.errors.full_messages.join(', ')}"
      end
    end
    
    puts "\n📈 Imported #{imported_count} sample records successfully!"
  end
end
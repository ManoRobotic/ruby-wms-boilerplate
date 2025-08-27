#!/usr/bin/env ruby

# Script to import inventory codes from DBF file
# Usage: ruby import_inventory_codes.rb

require_relative 'config/environment'
require 'dbf'

# Path to the DBF file
dbf_file_path = File.join(__dir__, 'dbf', 'ordprod.dbf')

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
  processed_count = 0
  
  # Process each record
  table.each_with_index do |record, index|
    begin
      processed_count += 1
      
      # Show progress every 50 records
      if (index + 1) % 50 == 0
        puts "🔄 Processed #{index + 1}/#{table.record_count} records..."
      end
      
      # Extract data from the record
      # CORRECT WAY: Use record[field_name] instead of record.attributes[field_name]
      no_ordp_value = record[:no_ordp]
      cve_copr_value = record[:cve_copr]
      cve_prod_value = record[:cve_prod]
      
      # Convert NO_ORDP to string (it's a number in the DBF)
      no_ordp_string = no_ordp_value.to_s
      
      # Ensure CVE_COPR and CVE_PROD are strings and stripped
      cve_copr_string = cve_copr_value.to_s.strip
      cve_prod_string = cve_prod_value.to_s.strip
      
      # Validate required fields
      if no_ordp_string.blank?
        puts "⚠️  Skipping record #{index + 1} with empty no_ordp"
        skipped_count += 1
        next
      end
      
      if cve_copr_string.blank?
        puts "⚠️  Skipping record #{index + 1} (NO_ORDP: #{no_ordp_string}) with empty cve_copr"
        skipped_count += 1
        next
      end
      
      if cve_prod_string.blank?
        puts "⚠️  Skipping record #{index + 1} (NO_ORDP: #{no_ordp_string}) with empty cve_prod"
        skipped_count += 1
        next
      end
      
      # Process FECH_CTO to handle invalid date values
      fech_cto_value = record[:fech_cto]
      # Handle cases where the date is false or invalid
      if fech_cto_value == false || fech_cto_value.nil? || fech_cto_value.to_s.strip.downcase == 'f'
        fech_cto_value = nil
      end
      
      attributes = {
        no_ordp: no_ordp_string,
        cve_copr: cve_copr_string,
        cve_prod: cve_prod_string,
        can_copr: record[:can_copr],
        tip_copr: record[:tip_copr],
        costo: record[:costo],
        fech_cto: fech_cto_value,
        cve_suc: record[:cve_suc]&.to_s&.strip,
        trans: record[:trans],
        lote: record[:lote]&.to_s&.strip,
        new_med: record[:new_med]&.to_s&.strip,
        new_copr: record[:new_copr]&.to_s&.strip,
        costo_rep: record[:costo_rep],
        partresp: record[:partresp],
        dmov: record[:dmov]&.to_s&.strip,
        partop: record[:partop],
        fcdres: record[:fcdres],
        undres: record[:undres]&.to_s&.strip
      }
      
      # Create or update the inventory code
      inventory_code = InventoryCode.find_or_initialize_by(no_ordp: attributes[:no_ordp])
      
      # Only update if attributes have changed
      if inventory_code.new_record? || inventory_code.attributes.slice(*attributes.keys.map(&:to_s)).values != attributes.values
        inventory_code.assign_attributes(attributes)
        
        if inventory_code.save
          if inventory_code.previous_changes.any?
            puts "✅ Updated inventory code: #{inventory_code.no_ordp}"
          else
            puts "➕ Created new inventory code: #{inventory_code.no_ordp}"
          end
          imported_count += 1
        else
          error_msg = inventory_code.errors.full_messages.join(', ')
          puts "❌ Failed to save inventory code #{attributes[:no_ordp]}: #{error_msg}"
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
  puts "   📊 Total processed: #{processed_count}"
  
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
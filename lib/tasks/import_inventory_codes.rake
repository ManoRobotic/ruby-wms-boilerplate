namespace :inventory do
  desc "Import inventory codes from DBF file"
  task import_from_dbf: :environment do
    require 'dbf'
    
    dbf_file = Rails.root.join('dbf', 'ordprod.dbf')
    
    unless File.exist?(dbf_file)
      puts "❌ DBF file not found: #{dbf_file}"
      exit 1
    end
    
    puts "📂 Reading DBF file: #{dbf_file}"
    
    # Clear existing data
    puts "🗑️  Clearing existing inventory codes..."
    InventoryCode.delete_all
    
    table = DBF::Table.new(dbf_file)
    imported_count = 0
    errors_count = 0
    
    puts "📊 Total records in DBF: #{table.record_count}"
    puts "🚀 Starting import..."
    
    table.each_with_index do |record, index|
      begin
        next if record.nil?
        
        # Map DBF fields to our model
        inventory_code = InventoryCode.create!(
          no_ordp: record.no_ordp&.strip,
          cve_copr: record.cve_copr&.strip,
          cve_prod: record.cve_prod&.strip,
          can_copr: record.can_copr,
          tip_copr: record.tip_copr,
          costo: record.costo,
          fech_cto: record.fech_cto,
          cve_suc: record.cve_suc&.strip,
          trans: record.trans,
          lote: record.lote&.strip,
          new_med: record.new_med&.strip,
          new_copr: record.new_copr&.strip,
          costo_rep: record.costo_rep,
          partresp: record.partresp,
          dmov: record.dmov&.strip,
          partop: record.partop,
          fcdres: record.fcdres,
          undres: record.undres&.strip
        )
        
        imported_count += 1
        
        # Progress indicator
        if (index + 1) % 50 == 0
          puts "✅ Processed #{index + 1} records... (#{imported_count} imported, #{errors_count} errors)"
        end
        
      rescue => e
        errors_count += 1
        puts "❌ Error importing record #{index + 1}: #{e.message}"
        puts "   Record data: #{record.to_h}" if record
      end
    end
    
    puts "\n🎉 Import completed!"
    puts "   📈 Successfully imported: #{imported_count} records"
    puts "   ❌ Errors: #{errors_count} records"
    puts "   💾 Total in database: #{InventoryCode.count} records"
    
    if errors_count > 0
      puts "\n⚠️  Some records failed to import. Check the logs above for details."
    end
  end

  desc "Show DBF file structure"
  task inspect_dbf: :environment do
    require 'dbf'
    
    dbf_file = Rails.root.join('dbf', 'ordprod.dbf')
    
    unless File.exist?(dbf_file)
      puts "❌ DBF file not found: #{dbf_file}"
      exit 1
    end
    
    table = DBF::Table.new(dbf_file)
    
    puts "📁 DBF File: #{dbf_file}"
    puts "📊 Record count: #{table.record_count}"
    puts "🗂️  Column count: #{table.column_count}"
    puts "\n📋 Column structure:"
    
    table.columns.each do |column|
      puts "  - #{column.name.ljust(15)} (#{column.type}, length: #{column.length})"
    end
    
    puts "\n📝 First 3 records:"
    table.first(3).each_with_index do |record, index|
      puts "\n  Record #{index + 1}:"
      record.to_h.each do |key, value|
        puts "    #{key.to_s.ljust(15)}: #{value.inspect}"
      end
    end
  end
end
# Configuración del entorno
set :environment, "development"
set :output, "log/cron.log"

# Configurar PATH para encontrar bundle y ruby
env :PATH, "/home/vscode/.local/share/mise/installs/ruby/3.3.4/bin:/home/vscode/.local/bin:#{ENV['PATH']}"
env :GEM_PATH, "/home/vscode/.local/share/mise/installs/ruby/3.3.4/lib/ruby/gems/3.3.0"

# # Job para sincronizar datos desde merged.xlsx cada minuto
# every 1.minute do
#   command "/workspaces/ruby-wms-boilerplate/bin/sync_excel_cron.sh"
# end

# # Job para actualizar métricas de producción cada 5 minutos
# every 5.minutes do
#   command "cd /workspaces/ruby-wms-boilerplate && /home/vscode/.local/share/mise/installs/ruby/3.3.4/bin/bundle exec bin/rails runner 'UpdateProductionMetricsJob.perform_now' >> log/cron.log 2>&1"
# end
#!/bin/bash
cd /workspaces/ruby-wms-boilerplate
export PATH="/home/vscode/.local/share/mise/installs/ruby/3.3.4/bin:$PATH"
export GEM_PATH="/home/vscode/.local/share/mise/installs/ruby/3.3.4/lib/ruby/gems/3.3.0"
/home/vscode/.local/share/mise/installs/ruby/3.3.4/bin/bundle exec bin/rails runner 'SyncExcelDataJob.perform_now' >> log/cron.log 2>&1
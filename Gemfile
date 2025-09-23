source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.6"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
gem "view_component"

gem "httparty"
# Use Redis adapter to run Action Cable in production
gem "redis"

gem "faker"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# DBF file reader
gem "dbf"

# for user accounts managment
gem "devise", "~> 4.9"

gem "font-awesome-sass", "~> 6.7"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.14"

gem "kaminari"

gem "mercadopago-sdk"

# Rate limiting and security
gem "rack-attack", "~> 6.6"

# Money handling
gem "money-rails", "~> 1.15"

# Structured logging
gem "ougai", "~> 2.0"

# Barcode generation
gem "barby", "~> 0.7.0"

# Excel file processing
gem "roo", "~> 2.10"
gem "chunky_png", "~> 1.3"

# Google Sheets API
gem "google_drive"

# PDF generation
gem "prawn"
gem "prawn-table"

# CORS handling
gem "rack-cors", "~> 3.0"

gem "aws-sdk-s3"


group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mswin mingw ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  gem "pry", "~> 0.15.2"

  gem "byebug"

  gem "dotenv-rails"

  # RSpec testing framework
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails", "~> 6.5"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Code coverage for RSpec
  gem "simplecov", require: false
  gem "simplecov-html", require: false

  # Controller testing utilities for RSpec
  gem "rails-controller-testing"
end

gem "dockerfile-rails", ">= 1.7", group: :development

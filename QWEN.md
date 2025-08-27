# Qwen Code Customization for Ruby WMS Boilerplate

This file contains custom instructions for Qwen Code to assist with the Ruby WMS (Warehouse Management System) Boilerplate project.

## Project Overview

This is a Ruby on Rails 8 application, serving as a Warehouse Management System. The presence of a Gemfile specifying Rails 8, `config.ru`, and `.ruby-version` indicates a standard Rails web application setup.

Key components from the Gemfile:
- **Framework**: Ruby on Rails 8.0.2
- **Database**: PostgreSQL (`pg` gem)
- **Web Server**: Puma
- **Frontend**: Hotwire (Turbo, Stimulus), Tailwind CSS, Importmaps
- **Authentication**: Devise for user management
- **Background Jobs**: Sidekiq
- **APIs/External Services**: MercadoPago SDK, Google Drive API, HTTParty
- **File Processing**: Roo (Excel), DBF, Prawn (PDF), Barby (Barcodes)
- **Utilities**: Kaminari (Pagination), Money-Rails, Ougai (Logging), Rack-Attack (Security)

The directory structure (`app/`, `spec/`) confirms this is a standard Rails application.

## Preferred Tools & Conventions

- **Framework**: Ruby on Rails 8
- **Database**: PostgreSQL with ActiveRecord ORM
- **Testing**: RSpec with FactoryBot and Faker (`.rspec` file present). Use RSpec conventions for writing or modifying tests.
- **Code Style**: RuboCop with Rails Omakase style (`rubocop-rails-omakase` gem). Adhere to the styles defined there.
- **Dependencies**: Manage dependencies via `Gemfile` and `bundle`.
- **Environment**: Ruby version 3.3.4 (`.ruby-version`).

## Workflow Guidance

- When modifying Ruby code, follow idiomatic Rails conventions and patterns.
- When adding new features, utilize the standard Rails directory structure (`app/models`, `app/controllers`, `app/views`, `app/services`).
- Always ensure new code or modifications are compatible with Ruby 3.3.4.
- If writing or modifying RSpec tests, follow the conventions in the `.rspec` configuration and place tests in the appropriate `spec/` subdirectories.
- Ensure code changes pass `rubocop` checks to maintain code style consistency.
- For database interactions, use ActiveRecord. Look for model files in `app/models` to understand the schema and relationships.
- For complex business logic, consider placing it in `app/services`.
- For background jobs, use Sidekiq workers placed in `app/jobs`.

## Example Commands for Verification

- **Install dependencies**: `bundle install`
- **Run tests**: `bundle exec rspec`
- **Lint code**: `bundle exec rubocop`
- **Start the application**: `bin/rails server` or `bundle exec puma`
- **Run migrations**: `bin/rails db:migrate`
- **Access console**: `bin/rails console`

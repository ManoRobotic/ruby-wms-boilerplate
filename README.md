# 🏭 WMS (Warehouse Management System) - Rails Application

> **A comprehensive warehouse management system built with Rails 8 for complete inventory and fulfillment operations**

[![Rails](https://img.shields.io/badge/Rails-8.0.2-red.svg)](https://rubyonrails.org/)
[![Ruby](https://img.shields.io/badge/Ruby-3.3.4-red.svg)](https://www.ruby-lang.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![Security](https://img.shields.io/badge/Security-Brakeman-green.svg)](https://brakemanscanner.org/)

## 🎯 What is this project?

This is a complete **Warehouse Management System (WMS)** designed to help you **manage inventory, fulfillment, and warehouse operations efficiently**. It includes all essential features for professional warehouse management, from multi-location inventory tracking to pick list optimization.

### ⚡ **Why use this WMS?**

- 🚀 **5-minute setup** - Uses Docker and devcontainers for development without complex configurations
- 📦 **Multi-warehouse** - Support for multiple warehouses, zones, and locations
- 📊 **Real-time tracking** - Complete inventory transaction audit trail
- 🎯 **Pick optimization** - Intelligent pick list generation and route optimization
- 📱 **Responsive** - Modern design with Tailwind CSS for mobile warehouse operations
- 🔐 **Secure** - Complete admin panel with role-based access
- 📈 **Analytics** - Comprehensive WMS dashboard with KPIs and alerts
- ✅ **Tested** - Complete test suite with RSpec and security scanning

---

## 🏭 Main WMS Features

### **Warehouse Management**
- 🏢 **Multi-warehouse support** with hierarchical organization
- 🏗️ **Zone management** (receiving, storage, picking, packing, shipping)
- 📍 **Location tracking** with coordinate system and capacity management
- 📊 **Utilization monitoring** with real-time capacity alerts
- 🎯 **Location optimization** for efficient space usage

### **Inventory Management**
- 📦 **Multi-location inventory** with real-time tracking
- 🏷️ **Batch/lot tracking** with expiry date management
- 📈 **Stock reservations** and allocation management
- ⚖️ **FIFO/LIFO/FEFO** inventory allocation methods
- 🔄 **Inventory transactions** with complete audit trail
- 📋 **Cycle counting** for inventory accuracy
- ⚠️ **Low stock alerts** and automatic replenishment

### **Order Fulfillment**
- 📋 **Pick list generation** with route optimization
- 🎯 **Task management** (putaway, picking, replenishment, cycle count)
- 📦 **Order processing** with warehouse assignment
- 🚚 **Shipment tracking** and fulfillment status
- ⏱️ **Performance metrics** and completion time tracking

### **Analytics & Reporting**
- 📊 **Real-time dashboard** with WMS KPIs
- 📈 **Inventory valuation** and movement reports
- 🎯 **Task performance** and productivity metrics
- 📦 **Pick list efficiency** and route optimization
- ⚠️ **Alert system** for exceptions and low stock

### **Technical Architecture**
- 🚀 **Rails 8.0.2** with latest improvements and performance optimizations
- 🐘 **PostgreSQL** with comprehensive indexing for WMS operations
- ⚡ **Stimulus + Turbo** for real-time warehouse operations
- 🎨 **Tailwind CSS** with responsive design for mobile warehouse operations
- 🔄 **Background jobs** (Sidekiq) for inventory synchronization and optimization
- 🏗️ **Service objects** for complex WMS business logic
- 🐳 **Docker** with devcontainers for consistent development
- 🧪 **RSpec** comprehensive test suite with 289 examples
- 🔒 **Brakeman** security scanning (0 vulnerabilities)
- 📊 **Performance monitoring** with 35+ database indexes

---

## 🚀 Quick Start

### **1. Prerequisites**
```bash
# Install Docker
https://www.docker.com/

# Install Devcontainers CLI
npm install -g @devcontainers/cli
# or with npx
npx install -g @devcontainers/cli
```

### **2. Clone and run**
```bash
# Clone the repository
git clone https://github.com/AlanAlvarez21/ruby-wms-boilerplate.git
cd ruby-wms-boilerplate

# Build the container (includes DB setup)
bin/build_container

# Seed the database with sample data
bin/rails db:seed

# Start the application
bin/dev
```

### **3. Ready! 🎉**
- **WMS Dashboard**: http://localhost:3000/admin
- **Admin Credentials**: 
  - Email: `admin@wmsapp.com`
  - Password: `password123`
- **Sample Data Includes**:
  - 2 Warehouses with 10 zones and 90 locations
  - 15 Products with WMS fields (SKU, dimensions, reorder points)
  - 10 Sample tasks (picking, putaway, replenishment, cycle count)
  - Inventory transactions and movement history

---

## 📁 WMS Project Structure

```
├── app/
│   ├── controllers/
│   │   ├── admin/
│   │   │   ├── warehouses_controller.rb      # Warehouse management
│   │   │   ├── zones_controller.rb           # Zone management
│   │   │   ├── locations_controller.rb       # Location management
│   │   │   ├── tasks_controller.rb           # Task assignment & tracking
│   │   │   ├── pick_lists_controller.rb      # Pick list management
│   │   │   ├── inventory_transactions_controller.rb
│   │   │   └── ...
│   │   └── admin_controller.rb       # WMS Dashboard
│   ├── models/
│   │   ├── warehouse.rb              # Multi-warehouse support
│   │   ├── zone.rb                   # Zone management (receiving, storage, etc.)
│   │   ├── location.rb               # Location tracking with coordinates
│   │   ├── task.rb                   # Task management system
│   │   ├── pick_list.rb              # Pick list optimization
│   │   ├── pick_list_item.rb         # Individual pick items
│   │   ├── inventory_transaction.rb  # Inventory audit trail
│   │   ├── product.rb                # Enhanced with WMS fields
│   │   ├── stock.rb                  # Multi-location inventory
│   │   ├── order.rb                  # Warehouse fulfillment
│   │   └── ...
│   ├── services/
│   │   ├── inventory_service.rb      # Stock allocation & movement
│   │   └── pick_list_service.rb      # Route optimization
│   ├── jobs/
│   │   ├── inventory_sync_job.rb     # Background inventory sync
│   │   └── pick_list_optimization_job.rb
│   ├── helpers/
│   │   └── wms_helper.rb             # WMS-specific view helpers
│   └── views/
│       └── admin/                    # WMS admin interface
├── db/
│   ├── migrate/                      # 15 WMS-specific migrations
│   └── seeds.rb                      # Complete WMS sample data
└── spec/                             # Comprehensive test suite
```

---

## 🏭 WMS Configuration

### **1. Environment Variables**
```bash
# Database configuration
export DATABASE_URL="postgresql://user:password@localhost:5432/wms_development"

# Rails configuration  
export RAILS_ENV="development"

# Background job processing
export REDIS_URL="redis://localhost:6379"
```

### **2. Warehouse Setup**
The system comes with sample warehouses, but you can customize:

```ruby
# In db/seeds.rb or through admin interface
warehouse = Warehouse.create!(
  name: "Main Distribution Center",
  code: "MDC",
  address: "123 Warehouse St, City, State"
)

# Add zones
receiving_zone = warehouse.zones.create!(
  name: "Receiving",
  code: "RCV",
  zone_type: "receiving"
)

# Add locations
receiving_zone.locations.create!(
  aisle: "A",
  bay: "01", 
  level: "01",
  capacity: 1000
)
```

---

## 🛠️ Development Commands

```bash
# Development
bin/dev                     # Server + Tailwind watcher
bin/rails server            # Rails server only
bin/rails tailwindcss:watch # Tailwind watcher only

# Database
bin/rails db:create         # Create database
bin/rails db:migrate        # Run migrations
bin/rails db:seed           # Seed with sample data
bin/rails db:reset          # Reset and seed

# Testing
bundle exec rspec           # Run tests (289 examples)
bin/brakeman               # Security analysis (0 vulnerabilities)
bin/rubocop                # Code linting

# WMS Operations
bin/rails runner "InventorySyncJob.perform_now"    # Sync inventory
bin/rails runner "PickListOptimizationJob.perform_now(pick_list_id)"  # Optimize routes

# Assets
bin/rails assets:precompile # Compile assets for production
bin/rails tailwindcss:build # Build Tailwind CSS
```

---

## 🎨 WMS Customization

### **1. Warehouse Layout Customization**
```ruby
# Configure zone types for your operation
Zone::ZONE_TYPES = %w[receiving storage picking packing shipping returns]

# Customize location coordinate system
Location.create!(
  zone: zone,
  aisle: "A",      # Aisle identifier
  bay: "01",       # Bay number within aisle  
  level: "01",     # Level/shelf within bay
  capacity: 1000   # Weight or volume capacity
)
```

### **2. Inventory Allocation Methods**
```ruby
# In app/services/inventory_service.rb
# Customize allocation strategy
ALLOCATION_METHODS = {
  fifo: -> { order(:created_at) },           # First In, First Out
  lifo: -> { order(created_at: :desc) },     # Last In, First Out  
  fefo: -> { order(:expiry_date) }           # First Expired, First Out
}
```

### **3. Task Types and Priorities**
```ruby
# Customize task types for your warehouse operations
Task::TASK_TYPES = %w[putaway picking replenishment cycle_count receiving shipping]
Task::PRIORITIES = %w[low medium high urgent]
```

### **4. WMS Translations**
```yaml
# In config/locales/es.yml (Spanish included)
es:
  wms:
    warehouse: "Almacén"
    pick_list: "Lista de Picking"
    task: "Tarea"
    inventory: "Inventario"
```

---

## 📊 WMS Administration Panel

The comprehensive WMS admin panel includes:

### **Dashboard & Analytics**
- **📈 WMS Dashboard**: Real-time KPIs, warehouse utilization, alerts
- **📊 Inventory Analytics**: Stock levels, movement reports, valuation
- **🎯 Task Metrics**: Performance tracking, completion rates, overdue alerts
- **📋 Pick List Analytics**: Route efficiency, completion times

### **Warehouse Operations**
- **🏢 Warehouse Management**: Multi-warehouse CRUD with utilization metrics  
- **🏗️ Zone Management**: Receiving, storage, picking, packing, shipping zones
- **📍 Location Management**: Coordinate tracking, capacity management
- **📦 Stock Management**: Multi-location inventory with batch/lot tracking

### **Task & Fulfillment**
- **🎯 Task Assignment**: Putaway, picking, replenishment, cycle count tasks
- **📋 Pick List Management**: Route optimization, progress tracking
- **📦 Order Processing**: Warehouse assignment, fulfillment status
- **🚚 Shipment Tracking**: Outbound logistics management

### **Inventory Control**
- **🔄 Transaction History**: Complete audit trail with filtering
- **📊 Movement Reports**: Inventory flow analysis with CSV export
- **⚠️ Alert System**: Low stock, expired products, overstock warnings
- **🏷️ Batch Tracking**: Lot management with expiry date monitoring

### **Access Control**
- **URL**: `/admin` 
- **Authentication**: Devise with admin user management
- **Security**: Role-based access, Brakeman scanned (0 vulnerabilities)
- **Responsive**: Mobile-optimized for warehouse floor operations

---

## 🧪 Testing

Complete test suite:

```bash
# Unit tests
bundle exec rspec spec/models/

# Controller tests
bundle exec rspec spec/controllers/

# Request tests
bundle exec rspec spec/requests/

# System tests (E2E)
bundle exec rspec spec/system/

# Coverage report
open coverage/index.html
```

---

## 🚀 Deployment

### **Heroku**
```bash
# Create application
heroku create your-store

# Configure variables
heroku config:set RAILS_MASTER_KEY=your_master_key
heroku config:set MERCADOPAGO_ACCESS_TOKEN=your_token

# Deploy
git push heroku main

# Initial setup
heroku run rails db:migrate
heroku run rails db:seed
```

🎯 WMS Seeds summary:
  🏢 Warehouses: 2
  🏗️ Zones: 10
  📍 Locations: 90
  📦 Products: 15 (with WMS fields)
  📊 Stock entries: 15 (multi-location)
  🎯 Tasks: 10 (various types)
  📋 Pick lists: Sample data
  🔄 Inventory transactions: Movement history
  👤 Admin users: 1

🔐 Admin credentials:
  Email: admin@wmsapp.com
  Password: password123
  

### **Docker Production**
```bash
# Build image
docker build -t your-store .

# Run
docker run -p 3000:3000 \
  -e RAILS_ENV=production \
  -e DATABASE_URL=postgres://... \
  your-store
```

---

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/AmazingFeature`)
3. **Commit** your changes (`git commit -m 'Add some AmazingFeature'`)
4. **Push** to the branch (`git push origin feature/AmazingFeature`)
5. **Create** a Pull Request

---

## 📝 Ideal Use Cases

This WMS is perfect for:

- 🏭 **Manufacturing facilities** with complex inventory tracking needs
- 📦 **Distribution centers** requiring multi-location inventory management
- 🚚 **3PL providers** managing inventory for multiple clients  
- 🏪 **Retail operations** with multiple warehouses and stores
- 💊 **Pharmaceutical companies** requiring batch/lot tracking and expiry management
- 🍕 **Food & beverage** operations with FEFO inventory rotation
- 🔧 **Spare parts management** with precise location tracking
- 📱 **E-commerce fulfillment** requiring pick optimization
- 🏗️ **Construction supply** with bulk inventory and location management
- 👨‍💻 **Developers** needing a professional WMS foundation

---

## 📋 WMS Roadmap

### **Completed Features:**
- [x] 🏢 Multi-warehouse management with zones and locations
- [x] 🔄 Complete inventory transaction audit trail
- [x] 🎯 Task management system with assignment and tracking
- [x] 📋 Pick list generation with route optimization
- [x] 🏷️ Batch/lot tracking with expiry date management  
- [x] 📊 Comprehensive WMS dashboard with real-time metrics
- [x] ⚖️ FIFO/LIFO/FEFO inventory allocation methods
- [x] 🔄 Background jobs for inventory sync and optimization
- [x] 📱 Mobile-responsive design for warehouse operations

### **Recently Added:**
- [x] 🔍 Advanced search and filtering system
- [x] 🔔 Notification system for alerts and updates
- [x] 📱 API endpoints for mobile warehouse applications

### **Future Enhancements:**
- [ ] 📊 Advanced analytics and machine learning insights
- [ ] 🤖 AI-powered demand forecasting  
- [ ] 📱 Native mobile app for warehouse operations
- [ ] 🏷️ RFID and barcode scanning integration
- [ ] 🚚 Advanced shipping carrier integrations
- [ ] 📦 Automated replenishment recommendations
- [ ] 🌍 Multi-language interface expansion
- [ ] 🔄 Integration with ERP systems (SAP, Oracle, etc.)

---

## 📄 License

This project is under the MIT license. See `LICENSE` for more details.

---

## 🆘 Support

- 📖 **Documentation**: [Project Wiki](https://github.com/AlanAlvarez21/ecommerce-boilerplate/wiki)
- 🐛 **Issues**: [Report problems](https://github.com/AlanAlvarez21/ecommerce-boilerplate/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/AlanAlvarez21/ecommerce-boilerplate/discussions)

---

**🏭 Deploy your WMS today!** This comprehensive system saves you months of warehouse management development.
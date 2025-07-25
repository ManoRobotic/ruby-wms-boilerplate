# 🛒 E-commerce Boilerplate - Rails Template

> **A complete e-commerce template built with Rails 8 to launch your online store in minutes**

[![Rails](https://img.shields.io/badge/Rails-8.0.1-red.svg)](https://rubyonrails.org/)
[![Ruby](https://img.shields.io/badge/Ruby-3.3.4-red.svg)](https://www.ruby-lang.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![CI](https://github.com/AlanAlvarez21/ecommerce-boilerplate/actions/workflows/ci.yml/badge.svg)](https://github.com/AlanAlvarez21/ecommerce-boilerplate/actions)

## 🎯 What is this project?

This is a complete e-commerce **boilerplate/template** designed to help you **launch your online store quickly**. It includes all the essential features you need to start selling products online, from inventory management to payment processing.

### ⚡ **Why use this boilerplate?**

- 🚀 **5-minute setup** - Uses Docker and devcontainers for development without complex configurations
- 💳 **Ready payments** - Complete integration with MercadoPago
- 📱 **Responsive** - Modern design with Tailwind CSS
- 🔐 **Admin panel** - Complete administration panel
- 📊 **Analytics** - Dashboard with sales metrics and reports
- 🌐 **Multi-language** - Support for Spanish and English
- ✅ **Tested** - Complete test suite with RSpec

---

## 🛍️ Main Features

### **For Customers (Frontend)**
- 🏪 **Product catalog** with categories and filters
- 🛒 **Shopping cart** with session management
- 💳 **Integrated checkout** with MercadoPago
- 📱 **Responsive design** optimized for mobile
- 🔍 **Intuitive search and navigation**

### **For Administrators (Backend)**
- 📊 **Dashboard with metrics** for sales and analytics
- 📦 **Product management** (full CRUD)
- 📂 **Category management** with images
- 📋 **Order management** and status tracking
- 📈 **Inventory control** and stock management
- 👥 **Admin user system** with Devise

### **Technical**
- 🚀 **Rails 8.0.1** with latest improvements
- 🐘 **PostgreSQL** as database
- ⚡ **Stimulus + Turbo** for interactivity
- 🎨 **Tailwind CSS** for styling
- 🐳 **Docker** with devcontainers
- 🧪 **RSpec** for testing
- 🔒 **Brakeman** for security
- 📈 **GitHub Actions** CI/CD

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
git clone https://github.com/AlanAlvarez21/ecommerce-boilerplate.git
cd ecommerce-boilerplate

# Build the container (includes DB setup)
bin/build_container

# Seed the database with sample data
bin/rails db:seed

# Start the application
bin/dev
```

### **3. Ready! 🎉**
- **Frontend**: http://localhost:3000
- **Admin Panel**: http://localhost:3000/admin
- **Admin Credentials**: 
  - Email: `admin@coinsapp.com`
  - Password: `password123`

---

## 📁 Project Structure

```
├── app/
│   ├── controllers/
│   │   ├── admin/          # Administration panel
│   │   ├── application_controller.rb
│   │   ├── cart_controller.rb
│   │   ├── checkout_controller.rb
│   │   └── ...
│   ├── models/
│   │   ├── admin.rb        # Admin users (Devise)
│   │   ├── category.rb     # Product categories
│   │   ├── product.rb      # Products
│   │   ├── order.rb        # Purchase orders
│   │   ├── stock.rb        # Inventory control
│   │   └── ...
│   ├── views/
│   │   ├── admin/          # Admin panel views
│   │   ├── layouts/        # Layouts (app and admin)
│   │   └── ...
│   └── services/
│       └── mercado_pago_sdk.rb  # Payment integration
├── config/
│   ├── routes.rb           # Application routes
│   └── ...
├── db/
│   ├── migrate/            # Migrations
│   └── seeds.rb            # Sample data
└── spec/                   # Tests with RSpec
```

---

## 💳 Payment Setup (MercadoPago)

### **1. Get credentials**
1. Create account at [MercadoPago Developers](https://www.mercadopago.com/developers)
2. Get your `ACCESS_TOKEN` and `PUBLIC_KEY`

### **2. Configure environment variables**
```bash
# In .env or in your system
export MERCADOPAGO_ACCESS_TOKEN="your_access_token"
export MERCADOPAGO_PUBLIC_KEY="your_public_key"
```

### **3. Configure webhook**
```bash
# Webhook URL for notifications
https://your-domain.com/webhooks/mercadopago
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
bundle exec rspec           # Run tests
bin/brakeman               # Security analysis
bin/rubocop                # Code linting

# Assets
bin/rails assets:precompile # Compile assets for production
bin/rails tailwindcss:build # Build Tailwind CSS
```

---

## 🎨 Customization

### **1. Change visual theme**
```scss
// In app/assets/stylesheets/application.tailwind.css
// Customize main colors
:root {
  --primary-color: #3b82f6;
  --secondary-color: #64748b;
}
```

### **2. Modify default products**
```ruby
# In db/seeds.rb
# Change categories and products according to your business
categories = Category.create!([
  {
    name: "Your Category",
    description: "Your category description",
    # ...
  }
])
```

### **3. Customize texts**
```yaml
# In config/locales/en.yml
en:
  app_name: "Your Store"
  meta_title: " - The best online store"
  # ...
```

---

## 📊 Administration Panel

The admin panel includes:

- **📈 Dashboard**: Sales metrics, recent orders, best-selling products
- **🛍️ Products**: Full CRUD with image management
- **📂 Categories**: Organization with catalog images
- **📋 Orders**: Status management and tracking
- **📦 Inventory**: Stock control per product
- **👥 Admins**: Administrator user management

### **Access**
- URL: `/admin`
- Authentication: Devise
- Permissions: Admin users only

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

This boilerplate is perfect for:

- 🏪 **Small/medium stores** that need quick online presence
- 💎 **Specialized products** (jewelry, collectibles, crafts)
- 🎨 **Artists and makers** who want to sell their creations
- 📚 **Educational or niche stores**
- 🚀 **E-commerce MVPs** to validate business ideas
- 👨‍💻 **Developers** who need a solid starting point

---

## 📋 Roadmap

### **Upcoming features:**
- [ ] 🔍 Advanced search with filters
- [ ] ⭐ Review and rating system
- [ ] 📧 Integrated email marketing
- [ ] 📱 PWA (Progressive Web App)
- [ ] 🌍 More payment gateways
- [ ] 📦 Shipping system integration
- [ ] 🤖 Basic chatbot
- [ ] 📊 Advanced analytics

---

## 📄 License

This project is under the MIT license. See `LICENSE` for more details.

---

## 🆘 Support

- 📖 **Documentation**: [Project Wiki](https://github.com/AlanAlvarez21/ecommerce-boilerplate/wiki)
- 🐛 **Issues**: [Report problems](https://github.com/AlanAlvarez21/ecommerce-boilerplate/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/AlanAlvarez21/ecommerce-boilerplate/discussions)

---

**🚀 Launch your e-commerce today!** This boilerplate saves you weeks of initial development.
# WMS (Warehouse Management System) - Rails Application

A comprehensive warehouse management system built with Rails 8 for inventory and fulfillment operations.

## Project Overview

This is a complete Warehouse Management System (WMS) designed to manage inventory, fulfillment, and warehouse operations efficiently. It includes essential features for professional warehouse management, from multi-location inventory tracking to pick list optimization.

### Key Features

- Quick Setup: Uses Docker and devcontainers for development without complex configurations.
- Multi-warehouse: Support for multiple warehouses, zones, and locations.
- Real-time Tracking: Complete inventory transaction audit trail.
- Pick Optimization: Intelligent pick list generation and route optimization.
- Responsive Design: Built with Tailwind CSS for mobile warehouse operations.
- Security: Complete admin panel with role-based access control.
- Analytics: Comprehensive WMS dashboard with KPIs and alerts.
- Quality Assurance: Complete test suite with RSpec and security scanning.

---

## Technical Architecture

### Core Frameworks

- Rails 8.0.2: Utilizing the latest performance optimizations.
- PostgreSQL: Comprehensive indexing for fast WMS operations.
- Stimulus + Turbo: For real-time reactive warehouse interfaces.
- Tailwind CSS: Modern, responsive utility-first CSS framework.

### Hardware Integration (Serial Communication)

The system features a decoupled hardware bridge that connects Rails with local scales and printers via ActionCable.

1. Rails Backend: Serves as a WebSocket (ActionCable) hub.
2. Python Client (final_working_serial_server.py): A local script that bridges physical serial ports to the cloud.

#### Running the Serial Client

To connect local hardware to the production environment:

```bash
python final_working_serial_server.py --url wss://wmsys.fly.dev/cable --token YOUR_TOKEN --device-id YOUR_ID
```

Available arguments:

- --url: WebSocket server address.
- --token: Authentication token from the Rails console.
- --device-id: Unique identifier for the local terminal.

---

## Production Deployment

### Fly.io Configuration

The application is deployed on Fly.io and optimized for high efficiency within limited resources.

- Memory: Configured for 256MB RAM with a 512MB Swap partition.
- Optimization: YJIT disabled and Malloc Arenas limited to 2 to minimize memory usage.
- Database: Managed PostgreSQL with automatic migrations on deploy.

Production URL: https://wmsys.fly.dev

---

## Development Setup

### Prerequisites

- Docker
- Devcontainers CLI

### Local Execution

1. Clone the repository.
2. Build the container: bin/build_container
3. Prepare database: bin/rails db:seed
4. Run development environment: bin/dev

Development URL: http://localhost:3000/admin

---

## Project Structure

- app/models: Core business logic (Warehouse, Zone, Location, Task, Stock).
- app/services: Complex operations like InventoryService and PickListService.
- app/channels: Real-time hardware communication (SerialConnectionChannel).
- lib/: Utility scripts for data import and system maintenance.

---

## Ideal Use Cases

- Manufacturing facilities with complex inventory tracking.
- Distribution centers with multi-location management.
- Pharmaceutical companies requiring batch and expiry tracking.
- Food and beverage operations requiring FEFO rotation.
- E-commerce fulfillment with pick route optimization.

---

## License

This project is released under the MIT License.

---


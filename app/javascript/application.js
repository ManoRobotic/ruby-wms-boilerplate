// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import { createConsumer } from "@rails/actioncable"

// Create ActionCable consumer and make it globally available
window.App = window.App || {}
window.App.cable = createConsumer()
window.createConsumer = createConsumer
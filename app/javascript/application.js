// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import { createConsumer } from "@rails/actioncable"

// Create ActionCable consumer and make it globally available
window.App = window.App || {}
window.App.cable = createConsumer()
window.createConsumer = createConsumer

// Custom Turbo Stream actions
document.addEventListener("turbo:load", function() {
  if (window.Turbo && window.Turbo.StreamActions) {
    // Define custom close action
    window.Turbo.StreamActions.close = function() {
      const targetId = this.getAttribute("target");
      const element = document.getElementById(targetId);
      if (element) {
        element.dispatchEvent(new CustomEvent("dialog:close"));
        console.log(`[TurboStreamAction] Dispatched dialog:close for ${targetId}`);
      } else {
        console.warn(`[TurboStreamAction] Element with ID ${targetId} not found for close action.`);
      }
    };
  }
});
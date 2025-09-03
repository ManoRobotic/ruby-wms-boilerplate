import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // No static targets needed if we're querying the DOM directly for elements inside the modal
  // static targets = ["numPrintsInput", "inventoryCodeId", "inventoryCodeNoOrdP"]

  connect() {
    console.log("Inventory Code controller connected!")
  }

  reloadTable() {
    location.reload()
  }

  openPrintModal(event) {
    event.preventDefault()
    const button = event.currentTarget
    const inventoryCodeId = button.dataset.inventoryCodeId
    const inventoryCodeNoOrdP = button.dataset.inventoryCodeNoOrdp

    // Access elements inside the modal using direct DOM queries
    document.querySelector('[data-inventory-code-target="inventoryCodeId"]').value = inventoryCodeId;
    document.querySelector('[data-inventory-code-target="inventoryCodeNoOrdP"]').value = inventoryCodeNoOrdP;
    document.querySelector('[data-inventory-code-target="numPrintsInput"]').value = 1; // Reset to 1 print by default

    // Open the modal using the dialog controller
    const printModalElement = document.querySelector('[data-dialog="print-modal"]').closest('[data-controller="dialog"]');
    if (printModalElement) {
      const dialogController = this.application.getControllerForElementAndIdentifier(printModalElement, 'dialog');
      if (dialogController) {
        dialogController.open("print-modal");
      } else {
        console.error("Dialog controller not found on the print modal element.");
      }
    } else {
      console.error("Print modal element not found.");
    }
  }

  print(event) {
    event.preventDefault()
    
    const inventoryCodeId = document.querySelector('[data-inventory-code-target="inventoryCodeId"]').value;
    const inventoryCodeNoOrdP = document.querySelector('[data-inventory-code-target="inventoryCodeNoOrdP"]').value;
    const numPrints = document.querySelector('[data-inventory-code-target="numPrintsInput"]').value;

    const printData = {
      inventoryCodeId: inventoryCodeId,
      inventoryCodeNoOrdP: inventoryCodeNoOrdP,
      numPrints: numPrints
    };

    console.log("--- Print Action (JSON) ---");
    console.log(JSON.stringify(printData, null, 2)); // Pretty print JSON
    console.log("---------------------------");

    // Close the modal
    const printModalElement = document.querySelector('[data-dialog="print-modal"]').closest('[data-controller="dialog"]');
    if (printModalElement) {
      const dialogController = this.application.getControllerForElementAndIdentifier(printModalElement, 'dialog');
      if (dialogController) {
        dialogController.close("print-modal");
      } else {
        console.error("Dialog controller not found on the print modal element.");
      }
    } else {
      console.error("Print modal element not found.");
    }
  }
}
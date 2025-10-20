import { Controller } from "@hotwired/stimulus";
import "sortablejs";

// Connects to data-controller="sortable-list"
export default class extends Controller {
  static targets = [ "sortableList", "removeButton", "listPick", "saveButton" ];

  connect() {
    new Sortable(this.sortableListTarget, {
      handle: ".drag-handle"
    });

    this.validate();
  }

  pick(event) {
    // Hide the picked element from the picker and Add(check/show) the element to the list (moving it to the end)
    event.currentTarget.classList.toggle("hidden");
    const listElement = this.element.querySelector(`[data-id="${event.currentTarget.dataset.pickId}"]`)
    listElement.querySelector('input[type="checkbox"]').checked = true;
    listElement.classList.toggle("hidden");
    listElement.parentElement.appendChild(listElement)
    
    this.validate();
  }

  remove(event) {
    event.preventDefault();

    // Remove(uncheck/hide) the element from the list and show it in the picker and show the element from in the picker
    const listElement = event.target.closest("[data-id]");
    listElement.querySelector('input[type="checkbox"]').checked = false;
    listElement.classList.toggle("hidden");
    this.element.querySelector(`[data-pick-id="${listElement.dataset.id}"]`).classList.toggle("hidden");

    this.validate();
  }

  validate() {
    // Collection must have minimum 1 scenario and maximum 6
    const selectedIds = Array.from(this.element.querySelectorAll('input[type="checkbox"]:checked'))
    this.saveButtonTarget.disabled = selectedIds.length < 1 || selectedIds.length > 6;
  }
}
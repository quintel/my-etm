import { Controller } from "@hotwired/stimulus";
import "sortablejs";

// Connects to data-controller="sortable-list"
export default class extends Controller {
  static targets = [ "list", "sortedIds", "removeButton", "listPick", "saveButton" ];

  connect() {
    new Sortable(this.listTarget, {
      handle: ".drag-handle",
      onEnd: this.dragEnd.bind(this)
    });

    this.updateSortedIds();
  }

  dragEnd(event) {
    this.updateSortedIds();
  }

  pick(event) {
    // Hide the picked element from the picker and show it in the list (moving it to the end)
    event.currentTarget.classList.toggle("hidden");
    const listElement = this.element.querySelector(`[data-id="${event.currentTarget.dataset.pickId}"]`)
    listElement.classList.toggle("hidden");
    listElement.parentElement.appendChild(listElement)
    
    this.updateSortedIds();
  }

  remove(event) {
    event.preventDefault();

    // Hide the element from the list and show it in the picker
    const listElement = event.target.closest("[data-id]");
    listElement.classList.toggle("hidden");
    this.element.querySelector(`[data-pick-id="${listElement.dataset.id}"]`).classList.toggle("hidden");

    this.updateSortedIds();
  }

  updateSortedIds() {
    const sortedIds = Array.from(this.element.querySelectorAll("[data-id]:not(.hidden)")).map(el => el.getAttribute("data-id"));
    this.sortedIdsTarget.value = sortedIds.join(",");

    // Collection must have minimum 1 scenario and maximum 6
    this.saveButtonTarget.disabled = sortedIds.length < 1 || sortedIds.length > 6;
  }
}
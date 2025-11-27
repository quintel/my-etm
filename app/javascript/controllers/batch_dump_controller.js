import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="batch-dump"
export default class extends Controller {
  static targets = ["hidden", "selectAll"]
  static values = { selected: Array }

  connect() {
    this.selectedValue = this.selectedValue || [];

    this.restoreSelections();

    // Listen for Turbo frame loads to restore selected checkboxes
    this.boundRestore = this.restoreSelections.bind(this);
    document.addEventListener("turbo:frame-load", this.boundRestore);
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundRestore);
  }

  // When checking "Select All", set the hidden field to all filtered ids
  // When unchecking "Select All" if still marked then clear the hidden field
  selectAll(event) {
    this.hiddenTarget.value = (event.target.checked) ? event.target.dataset.filteredIds : "";
    this.restoreSelections();
  }

  // When checking/unchecking a checkbox update the hidden field
  toggle(event) {
    const id = event.target.dataset.id;
    const selected = this.hiddenTarget.value ? this.hiddenTarget.value.split(",") : [];

    if (event.target.checked) {
      if (!selected.includes(id))
        selected.push(id);
    } else {
      const index = selected.indexOf(id);
      if (index !== -1)
        selected.splice(index, 1);
    }

    this.hiddenTarget.value = selected.join(",")

    // Update the "Select All" checkbox so it is checked only if all filtered ids are selected
    this.selectAllTarget.checked = this.sameCsvIds(this.hiddenTarget.value, this.selectAllTarget.dataset.filteredIds);
  }

  // Restore the selected checkboxes based on the hidden field
  restoreSelections() {
    const selected = this.hiddenTarget.value.split(",")

    this.element.querySelectorAll("#saved_scenarios_list input[type='checkbox']").forEach(cb => {
      const id = cb.dataset.id
      cb.checked = selected.includes(id)
    })
  }

  // Helper method to compare two comma separated lists of ids
  sameCsvIds(a, b) {
    const setA = new Set(a.split(",").map(s => s.trim()).filter(Boolean));
    const setB = new Set(b.split(",").map(s => s.trim()).filter(Boolean));

    if (setA.size !== setB.size) return false;

    return [...setA].every(v => setB.has(v));
  }
}

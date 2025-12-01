import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="batch-dump"
export default class extends Controller {
  static targets = [
    "hidden",
    "selectAll",
    "filteredIds",
    "export",
    "warning",
  ];

  static values = { selected: Array };

  connect() {
    // Only initialize if we have the targets
    if (!this.hasHiddenTarget || !this.hasFilteredIdsTarget) {
      return;
    }

    this.selectedValue = this.selectedValue || [];

    this.validateSelections();
    this.restoreSelections();

    // Listen for Turbo frame loads to restore selected checkboxes
    this.boundTurboFrame = this.turboFrameReloaded.bind(this);
    document.addEventListener("turbo:frame-load", this.boundTurboFrame);
  }

  disconnect() {
    if (this.boundTurboFrame) {
      document.removeEventListener("turbo:frame-load", this.boundTurboFrame);
    }
  }

  // When checking "Select All", set the hidden field to all filtered ids
  // When unchecking "Select All" if still marked then clear the hidden field
  selectAll(event) {
    this.hiddenTarget.value = (event.target.checked) ? this.filteredIdsTarget.value : "";
    this.validateSelections();
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

    this.hiddenTarget.value = selected.join(",");
    this.validateSelections();
  }

  validateSelections() {
    // Enable/disable the export button based on whether there are selected ids
    this.exportTarget.disabled = !this.hiddenTarget.value;

    // Update the "Select All" checkbox so it stays checked only when all filtered ids are selected
    this.selectAllTarget.checked = this.checkSameIds(this.hiddenTarget.value, this.filteredIdsTarget.value);
  }

  // Prevent export if there are multiple versions and "None" is selected
  validateVersion(event) {
    // If only one version the filter is not present
    const versionSelect = document.getElementById('version');
    if (!versionSelect) return true

    // more than 1 version (plus the 'None' option) AND None selected → block
    if (versionSelect.options.length > 2 && versionSelect.value === "") {
      event.preventDefault()
      alert("Please select a version before exporting.")
    }
  }

  // Restore the selected checkboxes based on the hidden field
  restoreSelections() {
    const selected = this.hiddenTarget.value.split(",");

    this.element.querySelectorAll("#saved_scenarios_list input[type='checkbox']").forEach(cb => {
      const id = cb.dataset.id;
      cb.checked = selected.includes(id);
    })
  }

  // Necessary actions when the turbo frame is reloaded due to pages/filters
  turboFrameReloaded() {
    this.hiddenTarget.value = this.getIntersectingIds(this.hiddenTarget.value, this.filteredIdsTarget.value);
    this.validateSelections();
    this.restoreSelections();
  }

  // Helper method to get intersecting ids from two comma-separated list
  getIntersectingIds(a, b) {
    const arrA = a.split(",");
    const setB = new Set(b.split(","));

    return arrA.filter(id => setB.has(id)).join(",");
  }

  // Helper method to check if same ids in two comma-separated lists
  checkSameIds(a, b) {
    const setA = new Set(a.split(","));
    const setB = new Set(b.split(","));

    if (setA.size !== setB.size) return false;

    return [...setA].every(v => setB.has(v));
  }
}

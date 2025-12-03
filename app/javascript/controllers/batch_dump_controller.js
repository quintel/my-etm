import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="batch-dump"
export default class extends Controller {
  static targets = [
    "hiddenContainer",
    "selectAll",
    "filtered",
    "export",
    "warning",
  ];

  static values = { 
    selectedIds: Array,
    filteredIds: Array
  };

  connect() {
    // Only initialize if we have the targets
    if (!this.filteredTarget) {
      return;
    }

    // Make sure the stimulus values are properly initialized
    this.filteredIdsValue = JSON.parse(this.filteredTarget.value);
    this.selectedIdsValue = this.selectedIdsValue || [];

    this.updateSelections();
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

  // When checking "Select All", set selected ids to all filtered ids
  // When unchecking "Select All" if still marked then clear all selected ids
  selectAll(event) {
    this.selectedIdsValue = (event.target.checked) ? this.filteredIdsValue : [];
    this.updateSelections();
    this.restoreSelections();
  }

  // When checking/unchecking a checkbox update the selected ids
  toggle(event) {
    const id = Number(event.target.dataset.id);

    if (event.target.checked) {
      if (!this.selectedIdsValue.includes(id))
        this.selectedIdsValue = [...this.selectedIdsValue, id]
    } else {
      this.selectedIdsValue = this.selectedIdsValue.filter(val => val !== id)
    }

    this.updateSelections();
  }

  updateSelections() {
    // Clear and recreate hidden fields for array submission
    this.hiddenContainerTarget.innerHTML = this.selectedIdsValue
      .map(id => `<input type="hidden" name="saved_scenario_ids[]" value="${id}">`)
      .join('');

    // Enable/disable the export button based on whether there are selected ids
    this.exportTarget.disabled = !this.selectedIdsValue.length;

    // Update the "Select All" checkbox so it stays checked only when all filtered ids are selected
    this.selectAllTarget.checked = this.checkSameIds(this.selectedIdsValue, this.filteredIdsValue);
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
    this.element.querySelectorAll("#saved_scenarios_list input[type='checkbox']").forEach(cb => {
      cb.checked = this.selectedIdsValue.includes(Number(cb.dataset.id));
    })
  }

  // Necessary actions when the turbo frame is reloaded due to pages/filters
  turboFrameReloaded() {
    this.filteredIdsValue = JSON.parse(this.filteredTarget.value)
    
    // Make sure the selected ids do not contain any filtered out ids when new filters are applied
    this.selectedIdsValue = this.selectedIdsValue.filter(id => this.filteredIdsValue.includes(id));
    
    this.updateSelections();
    this.restoreSelections();
  }

  // Helper method to check if same ids in two arrays (disregarding order)
  checkSameIds(a, b) {
    const setA = new Set(a);
    const setB = new Set(b);

    if (setA.size !== setB.size) return false;

    return [...setA].every(id => setB.has(id));
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="batch-dump"
export default class extends Controller {
  static targets = [
    "hiddenContainer",
    "selectAll",
    "filtered",
    "export",
    "checkbox",
  ];

  static values = {
    filteredIds: Array,
    selectedIds: Array
  };

  connect() {
    if (!this.hasFilteredTarget) return;

    this.filteredIdsValue = JSON.parse(this.filteredTarget.value);
    this.selectedIdsValue = this.selectedIdsValue || [];

    this.restoreCheckboxState();
    this.syncState();

    this.boundTurboFrame = this.turboFrameReloaded.bind(this);
    document.addEventListener("turbo:frame-load", this.boundTurboFrame);
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundTurboFrame);
  }

  // Get currently checked IDs from checkbox targets
  get checkedIds() {
    return this.checkboxTargets
      .filter(cb => cb.checked)
      .map(cb => Number(cb.dataset.batchDumpIdParam));
  }

  selectAll(event) {
    if (event.target.checked) {
      // Select all filtered IDs (across all pages)
      this.selectedIdsValue = [...this.filteredIdsValue];
    } else {
      // Deselect all
      this.selectedIdsValue = [];
    }

    this.restoreCheckboxState();
    this.syncState();
  }

  // Wwhen any individual checkbox is toggled
  toggle() {
    this.updateSelectedIds();
    this.syncState();
  }

  // Update the stored selectedIds from current checkbox state
  updateSelectedIds() {
    this.selectedIdsValue = this.checkedIds;
  }

  // Restore checkbox state from stored selectedIds (after turbo frame reload)
  restoreCheckboxState() {
    this.checkboxTargets.forEach(cb => {
      const id = Number(cb.dataset.batchDumpIdParam);
      cb.checked = this.selectedIdsValue.includes(id);
    });
  }

  // Sync all derived state from checkbox values
  syncState() {
    this.syncHiddenFields();
    this.syncSelectAllState();
    this.syncExportButton();
  }

  // Update hidden fields for form submission
  syncHiddenFields() {
    this.hiddenContainerTarget.innerHTML = this.selectedIdsValue
      .map(id => `<input type="hidden" name="saved_scenario_ids[]" value="${id}">`)
      .join('');
  }

  // Update "Select All" checkbox to reflect current state
  syncSelectAllState() {
    this.selectAllTarget.checked =
      this.selectedIdsValue.length > 0 &&
      this.checkSameIds(this.selectedIdsValue, this.filteredIdsValue);
  }

  // Enable/disable export button based on selection
  syncExportButton() {
    this.exportTarget.disabled = this.selectedIdsValue.length === 0;
  }

  // Prevent export if there are multiple versions and "None" is selected
  validateVersion(event) {
    const versionSelect = document.getElementById('version');
    if (!versionSelect) return;

    if (versionSelect.options.length > 2 && versionSelect.value === "") {
      event.preventDefault();
      alert("Please select a version before exporting.");
    }
  }

  // Handle turbo frame reloads (pagination/filtering)
  turboFrameReloaded() {
    this.filteredIdsValue = JSON.parse(this.filteredTarget.value);

    // Remove any selected IDs that are no longer in the filtered set
    this.selectedIdsValue = this.selectedIdsValue.filter(id =>
      this.filteredIdsValue.includes(id)
    );

    // Restore checkbox state for the new elements
    this.restoreCheckboxState();
    this.syncState();
  }

  // Helper method to check if same ids in two arrays (disregarding order)
  checkSameIds(a, b) {
    if (a.length !== b.length) return false;
    const setB = new Set(b);
    return a.every(id => setB.has(id));
  }
}

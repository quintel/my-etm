import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="batch-dump"
export default class extends Controller {
  static targets = ["selectAll", "export", "warning"];
  static values = { selected: { type: Array, default: [] } };

  connect() {
    this.restoreSelections();
    this.validateSelections();

    // Listen for Turbo frame loads
    this.element.addEventListener("turbo:frame-load", () => this.handleFrameReload());

    // Sync hidden inputs before form submission
    this.element.addEventListener("submit", () => this.syncHiddenInputs());
  }

  // When checking "Select All", select all filtered ids
  selectAll(event) {
    this.selectedValue = event.target.checked ? this.filteredIds : [];
    this.restoreSelections();
    this.validateSelections();
  }

  // Toggle individual checkbox
  toggle(event) {
    const id = String(event.target.dataset.id);

    if (event.target.checked) {
      if (!this.selectedValue.includes(id)) {
        this.selectedValue = [...this.selectedValue, id];
      }
    } else {
      this.selectedValue = this.selectedValue.filter(selectedId => selectedId !== id);
    }

    this.validateSelections();
  }

  validateSelections() {
    // Enable/disable export button
    this.exportTarget.disabled = this.selectedValue.length === 0;

    // Update "Select All" checkbox state
    if (this.hasSelectAllTarget) {
      const allSelected = this.filteredIds.length > 0 &&
                         this.filteredIds.every(id => this.selectedValue.includes(id));
      this.selectAllTarget.checked = allSelected;
    }
  }

  // Prevent export if there are multiple versions and "None" is selected
  validateVersion(event) {
    const versionSelect = document.getElementById('version');
    if (!versionSelect) return true;

    if (versionSelect.options.length > 2 && versionSelect.value === "") {
      event.preventDefault();
      alert("Please select a version before exporting.");
    }
  }

  // Restore checkbox states from selected IDs
  restoreSelections() {
    this.element.querySelectorAll("#saved_scenarios_list input[type='checkbox']").forEach(cb => {
      cb.checked = this.selectedValue.includes(String(cb.dataset.id));
    });
  }

  // Handle Turbo frame reload (pagination/filtering)
  handleFrameReload() {
    // Keep only selected IDs that are still in the filtered set
    this.selectedValue = this.selectedValue.filter(id => this.filteredIds.includes(id));
    this.restoreSelections();
    this.validateSelections();
  }

  // Create hidden inputs just before form submission
  syncHiddenInputs() {
    // Remove any existing hidden inputs
    this.element.querySelectorAll('input[name="saved_scenario_ids[]"]').forEach(input => input.remove());

    // Create hidden input for each selected ID
    const fragment = document.createDocumentFragment();
    this.selectedValue.forEach(id => {
      const input = document.createElement('input');
      input.type = 'hidden';
      input.name = 'saved_scenario_ids[]';
      input.value = id;
      fragment.appendChild(input);
    });
    this.element.appendChild(fragment);
  }

  // Get filtered IDs from turbo frame data attribute
  get filteredIds() {
    const turboFrame = document.getElementById('saved_scenarios');
    if (!turboFrame) return [];

    const data = turboFrame.dataset.batchDumpFilteredIds;
    return data ? JSON.parse(data).map(String) : [];
  }
}

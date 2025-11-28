import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="batch-dump"
export default class extends Controller {
  static targets = ["selectAll", "export", "warning"];
  static values = {
    selected: { type: Array, default: [] },
    versions: { type: Object, default: {} }  // Map of scenario_id -> version_id
  };

  connect() {
    this.restoreSelections();
    this.validateSelections();

    // Listen for Turbo frame loads
    this.element.addEventListener("turbo:frame-load", () => this.handleFrameReload());

    // Sync hidden inputs before form submission
    this.element.addEventListener("submit", () => this.syncHiddenInputs());
  }

  // When checking "Select All", select all filtered ids across all pages
  async selectAll(event) {
    if (event.target.checked) {
      // Fetch all filtered scenario IDs from the server
      try {
        const url = new URL(window.location.href);
        url.pathname = url.pathname.replace(/\/admin\/saved_scenarios.*/, '/admin/saved_scenarios/list');
        url.searchParams.set('format', 'json');

        const response = await fetch(url.toString());
        const data = await response.json();

        // Extract IDs and build version map
        this.selectedValue = data.scenario_ids.map(s => String(s.id));
        const versions = {};
        data.scenario_ids.forEach(s => {
          versions[String(s.id)] = String(s.version_id);
        });
        this.versionsValue = versions;
      } catch (error) {
        console.error('Failed to fetch filtered scenarios:', error);
        // Fallback to current page only
        this.selectedValue = this.filteredIds;
        const versions = {};
        this.element.querySelectorAll("#saved_scenarios_list input[type='checkbox']").forEach(cb => {
          versions[String(cb.dataset.id)] = String(cb.dataset.versionId);
        });
        this.versionsValue = versions;
      }
    } else {
      this.selectedValue = [];
      this.versionsValue = {};
    }
    this.restoreSelections();
    this.validateSelections();
  }

  // Toggle individual checkbox
  toggle(event) {
    const id = String(event.target.dataset.id);
    const versionId = String(event.target.dataset.versionId);

    if (event.target.checked) {
      if (!this.selectedValue.includes(id)) {
        this.selectedValue = [...this.selectedValue, id];
        this.versionsValue = { ...this.versionsValue, [id]: versionId };
      }
    } else {
      this.selectedValue = this.selectedValue.filter(selectedId => selectedId !== id);
      const newVersions = { ...this.versionsValue };
      delete newVersions[id];
      this.versionsValue = newVersions;
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

  // Prevent export if selected scenarios have different versions
  validateVersion(event) {
    if (this.selectedValue.length === 0) {
      event.preventDefault();
      alert("Please select at least one scenario to export.");
      return;
    }

    // Get unique version IDs from selected scenarios
    const selectedVersions = new Set(
      this.selectedValue.map(id => this.versionsValue[id]).filter(Boolean)
    );

    if (selectedVersions.size > 1) {
      event.preventDefault();
      alert("Cannot export scenarios from different versions. Please select scenarios from the same version.");
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

    // Clean up versions map to remove unselected scenarios
    const newVersions = {};
    this.selectedValue.forEach(id => {
      if (this.versionsValue[id]) {
        newVersions[id] = this.versionsValue[id];
      }
    });
    this.versionsValue = newVersions;

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

  // Get filtered IDs from visible checkboxes on the current page
  get filteredIds() {
    const checkboxes = this.element.querySelectorAll("#saved_scenarios_list input[type='checkbox']");
    return Array.from(checkboxes).map(cb => String(cb.dataset.id));
  }
}

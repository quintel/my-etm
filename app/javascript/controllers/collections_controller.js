import { Controller } from "@hotwired/stimulus";
import "sortablejs";

// Connects to data-controller="collections"
export default class extends Controller {
  static targets = [
    'hiddenVersion',
    'versionSelect',
    'sortableList',
    'sortableListLabel',
    'listPicker',
    'listPickerLabel',
    'listPick',
    'saveButton'
  ];

  connect() {
    new Sortable(this.sortableListTarget, {
      handle: '.drag-handle'
    });

    this.validate();
    this.updateVersion();
  }

  pick(event) {
    // Hide the picked element from the picker and Add(check/show) the element to the list (moving it to the end)
    event.currentTarget.classList.toggle('hidden');
    const listElement = this.element.querySelector(`[data-id="${event.currentTarget.dataset.pickId}"]`)
    listElement.querySelector('input[type="checkbox"]').checked = true;
    listElement.classList.toggle('hidden');
    listElement.parentElement.appendChild(listElement)
    
    this.validate();
  }

  remove(event) {
    event.preventDefault();

    // Remove(uncheck/hide) the element from the list and show it in the picker and show the element from in the picker
    const listElement = event.target.closest('[data-id]');
    listElement.querySelector('input[type="checkbox"]').checked = false;
    listElement.classList.toggle('hidden');
    const pickerElement = this.listPickTargets.find(el => el.dataset['pickId'] === listElement.dataset.id);
    pickerElement.classList.toggle('hidden');

    this.validate();
  }

  changeVersion(event) {
    this.updateVersion()
  }

  validate() {
    // List must have minimum 1 element and maximum 6
    const numSelected = this.element.querySelectorAll('input[type="checkbox"]:checked').length
    this.listPickerTarget.style.pointerEvents = (numSelected >= 6) ? 'none' : 'auto';
    this.saveButtonTarget.disabled = numSelected < 1 || numSelected > 6;

    // Update labels visibility for a nicer UI
    const numAvailable = this.listPickerTarget.querySelectorAll('[data-pick-id]:not(.hidden)').length;
    this.sortableListLabelTarget.classList.toggle('hidden', numSelected < 1);
    this.listPickerLabelTarget.classList.toggle('hidden', numAvailable < 1);

    // Lock the version selection when the list is not empty
    if (this.hasVersionSelectTarget) {
      this.versionSelectTarget.disabled = (numSelected > 0)
    }
  }

  updateVersion() {
    // Version field is only available in new collections
    if (!this.hasHiddenVersionTarget) return;

    // Version is hidden and sometimes acompanied by a selector (to have disable capability) so they must align
    if (this.hasVersionSelectTarget) {
      this.hiddenVersionTarget.value = this.versionSelectTarget.value;
    }

    // Filter available picks acordingly
    this.listPickTargets.forEach((listPick) => {
      listPick.classList.toggle('hidden', listPick.dataset.version !== this.hiddenVersionTarget.value);
    })
  }
}
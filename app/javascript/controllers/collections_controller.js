import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scenario", "versionSelect", "checkbox", "saveButton"]

  connect() {
    this.filterScenarios()
    this.validate()
  }

  versionChanged(event) {
    this.filterScenarios()
    this.validate()
  }

  filterScenarios() {
    if (!this.hasVersionSelectTarget) {
      return
    }
    const selectedVersion = this.versionSelectTarget.value

    this.scenarioTargets.forEach((scenarioElement) => {
      const scenarioVersion = scenarioElement.dataset.version

      if (scenarioVersion === selectedVersion) {
        scenarioElement.style.display = ''
      } else {
        scenarioElement.style.display = 'none'
      }
    })
  }

  validate() {
    let checked = this.checkboxTargets.filter((box) => box.checked);
    let unchecked = this.checkboxTargets.filter((box) => !box.checked);
    if (this.hasSaveButtonTarget) {
      this.saveButtonTarget.disabled = checked.length === 0;
    }
    if (checked.length == 6) {
      unchecked.forEach((box) => box.disabled = true);
    } else {
      unchecked.forEach((box) => box.disabled = false);
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scenario", "versionSelect"]

  connect() {
    this.validate()
    this.filterScenarios()
  }

  versionChanged(event) {
    this.filterScenarios()
  }

  filterScenarios() {
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
    if (checked.length == 6) {
      unchecked.forEach((box) => box.disabled = true);
    } else {
      unchecked.forEach((box) => box.disabled = false);
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scenario", "versionSelect"]

  connect() {
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
}

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "content", "editcontent", "controls", "editcontrols",
    "restorecontrols"
  ]

  showEdit(event) {
    this.editcontentTarget.classList.remove("hidden")
    this.editcontrolsTarget.classList.remove("hidden")
    this.controlsTarget.classList.add("hidden")
    this.contentTarget.classList.add("hidden")
  }

  hideEdit(event) {
    this.editcontentTarget.classList.add("hidden")
    this.editcontrolsTarget.classList.add("hidden")
    this.controlsTarget.classList.remove("hidden")
    this.contentTarget.classList.remove("hidden")
  }

  showRestore(event) {
    this.restorecontrolsTarget.classList.remove("hidden")
    this.controlsTarget.classList.add("hidden")
  }

  hideRestore(event) {
    this.restorecontrolsTarget.classList.add("hidden")
    this.controlsTarget.classList.remove("hidden")
  }
}

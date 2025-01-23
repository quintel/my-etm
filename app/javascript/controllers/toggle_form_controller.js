import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content", "editcontent", "controls", "editcontrols"]

  show(event) {
    this.editcontentTarget.classList.remove("hidden")
    this.editcontrolsTarget.classList.remove("hidden")
    this.controlsTarget.classList.add("hidden")
    this.contentTarget.classList.add("hidden")
  }

  hide(event) {
    this.editcontentTarget.classList.add("hidden")
    this.editcontrolsTarget.classList.add("hidden")
    this.controlsTarget.classList.remove("hidden")
    this.contentTarget.classList.remove("hidden")
  }
}

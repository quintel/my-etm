import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content"]

  show(event) {
    this.contentTarget.classList.remove("hidden")
    event.currentTarget.classList.add("hidden")
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"];

  connect() {
    this.validate();
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

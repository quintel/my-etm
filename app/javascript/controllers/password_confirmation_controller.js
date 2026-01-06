import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["password", "confirmation"];
  static values = { mismatchMessage: String };

  connect() {
    this.validate();
  }

  validate() {
    const password = this.passwordTarget.value;
    const confirmation = this.confirmationTarget.value;

    if (confirmation.length > 0 && password !== confirmation) {
      this.confirmationTarget.setCustomValidity(this.mismatchMessageValue);
    } else {
      this.confirmationTarget.setCustomValidity("");
    }
  }
}

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["password", "confirmation", "message"];
  static values = { mismatchMessage: String };

  connect() {
    this.validate();
  }


  validate() {
    const mismatch =
      this.confirmationTarget.value.length > 0 &&
      this.passwordTarget.value !== this.confirmationTarget.value;

    this.confirmationTarget.setCustomValidity(mismatch ? this.mismatchMessageValue : "");
    this.messageTarget.textContent = mismatch ? this.mismatchMessageValue : "";
    this.messageTarget.classList.toggle("hidden", !mismatch);
  }
}

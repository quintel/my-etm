import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["search", "hiddenInput", "datalist"]

  connect() {
    this.searchTarget.addEventListener("input", this.updateUserId.bind(this));
  }

  updateUserId() {
    const selectedOption = Array.from(this.datalistTarget.options).find(
      option => option.value === this.searchTarget.value
    );
    this.hiddenInputTarget.value = selectedOption ? selectedOption.getAttribute("data-id") : "";
  }
}

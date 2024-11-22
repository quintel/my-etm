import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ['button']

  select() {
    this.buttonTarget.click();
  }
}

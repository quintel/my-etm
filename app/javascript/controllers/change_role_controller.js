import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="change_role"
export default class extends Controller {

  connect() {
  }

  submit() {
    this.element.requestSubmit();
  }
}

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  select() {
    this.element.select();
  }
}

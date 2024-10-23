import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card"];
  static values = { url: String };

  show() {
    if (this.hasCardTarget) {
      this.cardTarget.classList.remove("opacity-0");
      this.cardTarget.classList.add("delay-500");
      this.cardTarget.classList.add("opacity-100");
    } else {
      fetch(this.urlValue)
        .then((r) => r.text())
        .then((html) => {
          const fragment = document
            .createRange()
            .createContextualFragment(html);

          this.element.appendChild(fragment);
        });
    }
  }

  hide() {
    if (this.hasCardTarget) {
      this.cardTarget.classList.add("opacity-0");
      this.cardTarget.classList.remove("delay-500");
      this.cardTarget.classList.remove("opacity-100");
    }
  }

  disconnect() {
    if (this.hasCardTarget) {
      this.cardTarget.remove();
    }
  }
}


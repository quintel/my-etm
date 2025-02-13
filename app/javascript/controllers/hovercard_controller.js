import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card"];
  static values = { url: String };

  show() {
    if (this.hasCardTarget) {
      setTimeout(() => {
        this.cardTarget.classList.remove("hidden", "pointer-events-none");
        this.cardTarget.classList.add("opacity-100");
        this.cardTarget.classList.remove("opacity-0");
      }, 150);
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
      this.cardTarget.classList.add("opacity-0", "pointer-events-none");
      this.cardTarget.classList.remove("opacity-100");
      setTimeout(() => {
        this.cardTarget.classList.add("hidden");
      }, 300);
    }
  }

  disconnect() {
    if (this.hasCardTarget) {
      this.cardTarget.remove();
    }
  }
}

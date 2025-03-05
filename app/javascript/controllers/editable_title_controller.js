import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { url: String };

  connect() {
    this.originalText = this.element.innerText.trim();
    this.element.setAttribute("spellcheck", "false");
  }

  async update(event) {
    if (event.type === "keydown" && event.key === "Enter") {
      event.preventDefault();
      this.element.blur();
      return;
    }

    const newTitle = this.element.innerText.trim();

    if (newTitle === "" || newTitle === this.originalText) {
      this.element.innerText = this.originalText;
      return;
    }

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({ collection: { title: newTitle } })
      });

      if (!response.ok) {
        throw new Error("Failed to update title");
      }

      this.originalText = newTitle;
    } catch (error) {
      alert("Error updating title");
      this.element.innerText = this.originalText;
    }
  }
}

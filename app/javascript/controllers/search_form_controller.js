import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "form" ]

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, 200)
  }

  clear(event) {
    event.preventDefault()

    this.formTarget.reset()

    // Uncheck all checkboxes
    this.formTarget.querySelectorAll('input[type="checkbox"]').forEach(cb => {
      cb.checked = false
    })

    // Reset all select elements to first option
    this.formTarget.querySelectorAll('select').forEach(select => {
      select.selectedIndex = 0
    })

    this.formTarget.requestSubmit()
  }
}

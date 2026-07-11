import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["differentHoursFields"]

  connect() {
    this.updateFields()
  }

  typeChanged() {
    this.updateFields()
  }

  updateFields() {
    const isDifferentHours = this.element.querySelector('input[name*="closed"][value="0"]')?.checked
    this.differentHoursFieldsTarget.style.display = isDifferentHours ? "" : "none"
  }
}

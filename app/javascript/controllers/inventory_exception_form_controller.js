import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["qtyFields", "timeFields"]

  connect() {
    this.updateFields()
  }

  typeChanged() {
    this.updateFields()
  }

  updateFields() {
    const selected = this.element.querySelector('input[name="product_exception[exception_type]"]:checked')?.value
    const showQty  = selected === "override" || selected === "add"
    const showTime = selected === "override"

    this.qtyFieldsTarget.style.display  = showQty  ? "" : "none"
    this.timeFieldsTarget.style.display = showTime ? "" : "none"

    this.element.querySelectorAll(".type-opt").forEach(label => {
      const radio = label.querySelector("input[type=radio]")
      label.classList.toggle("sel", radio?.checked ?? false)
    })
  }
}

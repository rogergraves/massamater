import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["newForm", "newBtn"]
  static values  = { openId: Number }

  connect() {
    if (this.openIdValue) this.openProduct(this.openIdValue)
  }

  showNew() {
    this.newFormTarget.style.display = ""
    this.newBtnTarget.style.display  = "none"
  }

  hideNew() {
    this.newFormTarget.style.display = "none"
    this.newBtnTarget.style.display  = ""
  }

  open(event) {
    this.openProduct(event.currentTarget.dataset.productId)
  }

  openWithDay(event) {
    const { productId, dayNum } = event.currentTarget.dataset
    this.openProduct(productId)
    const form = document.getElementById(`product-form-${productId}`)
    const cb = form?.querySelector(`input[name="day_of_week[]"][value="${dayNum}"]`)
    if (cb && !cb.disabled) {
      cb.checked = !cb.checked
      cb.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  close(event) {
    const id = event.currentTarget.dataset.productId
    document.getElementById(`product-summary-${id}`).style.display = ""
    document.getElementById(`product-form-${id}`).style.display    = "none"
  }

  toggleDayBox(event) {
    event.currentTarget.closest("label").classList.toggle("checked", event.currentTarget.checked)
  }

  toggleActive(event) {
    event.currentTarget.closest(".toggle").classList.toggle("off", !event.currentTarget.checked)
  }

  uploadPhoto(event) {
    event.currentTarget.closest("form").requestSubmit()
  }

  openProduct(id) {
    document.getElementById(`product-summary-${id}`).style.display = "none"
    document.getElementById(`product-form-${id}`).style.display    = ""
  }
}

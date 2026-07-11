import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event) {
    const row    = event.currentTarget.closest(".day-row")
    const isOpen = event.currentTarget.checked
    row.classList.toggle("closed-row", !isOpen)
    row.querySelectorAll(".time-in").forEach(el => el.disabled = !isOpen)
    const pill = row.querySelector(".closed-pill")
    if (pill) pill.style.display = isOpen ? "none" : ""
    const toggle = row.querySelector(".toggle")
    toggle.classList.toggle("off", !isOpen)
  }
}

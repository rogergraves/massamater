import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "row"]

  filter() {
    const q = this.inputTarget.value.trim().toLowerCase()
    this.rowTargets.forEach(row => {
      const text = (row.dataset.filterText || row.textContent).toLowerCase()
      row.hidden = q.length > 0 && !text.includes(q)
    })
  }
}

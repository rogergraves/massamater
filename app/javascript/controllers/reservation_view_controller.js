import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "listBtn", "gridBtn"]

  connect() {
    const saved = localStorage.getItem("reservation_view") || "list"
    this.#apply(saved)
  }

  showList() { this.#apply("list") }
  showGrid() { this.#apply("grid") }

  #apply(mode) {
    localStorage.setItem("reservation_view", mode)
    this.containerTarget.classList.toggle("res-list", mode === "list")
    this.containerTarget.classList.toggle("res-grid", mode === "grid")
    this.listBtnTarget.classList.toggle("view-btn--active", mode === "list")
    this.gridBtnTarget.classList.toggle("view-btn--active", mode === "grid")
    this.element.style.overflow = mode === "grid" ? "visible" : ""
  }
}

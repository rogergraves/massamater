import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "phone", "name", "nameHint", "source",
    "date", "pickupTime",
    "productsContainer",
    "collapsibleHead", "collapsibleBody",
    "stepperVal", "quantity",
    "note", "submit"
  ]
  static values = { lookupUrl: String }

  connect() {
    this._userFound = false
    this._existingReservation = null
    this.#updateSubmit()
    if (this.dateTarget.value) this.loadProducts()
  }

  // ── Phone lookup ───────────────────────────────────────────────────────────

  async lookupPhone() {
    const phone = this.phoneTarget.value.trim()
    if (!phone) return

    this.nameTarget.disabled = true
    this.nameTarget.placeholder = "Checking…"
    this.#updateSubmit(true)

    try {
      const data = await this.#fetchLookup(phone, this.dateTarget.value)

      if (data.found) {
        this.nameTarget.value = data.name || ""
        this.nameTarget.disabled = false
        this.#hideNameHint()
        this._userFound = true
      } else {
        this.nameTarget.value = ""
        this.nameTarget.disabled = false
        this.nameTarget.placeholder = ""
        this.#showNameHint()
        this._userFound = false
      }

      if (data.source && this.hasSourceTarget) {
        const radio = this.sourceTarget.querySelector(`input[value="${data.source}"]`)
        if (radio) radio.checked = true
      }

      this._existingReservation = data.reservation || null
      this.#applyExistingReservation()
      this.#updateSubmitLabel()
    } catch (_err) {
      this.nameTarget.value = ""
      this.nameTarget.disabled = false
      this.nameTarget.placeholder = ""
      this.#hideNameHint()
      this._userFound = false
      this._existingReservation = null
    } finally {
      this.#updateSubmit()
    }
  }

  phoneChanged() {
    this.#updateSubmit()
  }

  nameTyped() {
    if (this.nameTarget.value.trim().length > 0) {
      this.#hideNameHint()
    }
  }

  // ── Product loading ────────────────────────────────────────────────────────

  async loadProducts() {
    const date = this.dateTarget.value
    if (!date) return

    this.productsContainerTarget.innerHTML = ""
    this.#updateSubmit(true)

    try {
      const phone = this.phoneTarget.value.trim()
      const [html, lookupData] = await Promise.all([
        this.#fetchProducts(date),
        (phone && this._userFound) ? this.#fetchLookup(phone, date) : Promise.resolve(null)
      ])

      this.productsContainerTarget.innerHTML = html
      const card = this.productsContainerTarget.querySelector("[data-opens-at]")
      this.#buildTimeSlots(card?.dataset?.opensAt, card?.dataset?.closesAt)

      if (lookupData !== null) {
        this._existingReservation = lookupData.reservation || null
        this.#updateSubmitLabel()
      }

      this.#applyExistingReservation()
    } catch (_err) {
      // silently ignore network errors
    } finally {
      this.#updateSubmit()
    }
  }

  // ── Collapsible sections ───────────────────────────────────────────────────

  toggleSection(event) {
    const head  = event.currentTarget
    const idx   = this.collapsibleHeadTargets.indexOf(head)
    const body  = this.collapsibleBodyTargets[idx]
    const toggle = head.querySelector(".collapsible-toggle")
    if (!body) return

    const isHidden = body.classList.contains("hidden")
    body.classList.toggle("hidden", !isHidden)
    if (toggle) {
      toggle.textContent = isHidden ? "Hide" : "Show"
    }
  }

  // ── Override checkbox ──────────────────────────────────────────────────────

  toggleOverride(event) {
    const cb   = event.currentTarget
    const body = cb.closest(".collapsible-body")
    if (!body) return

    const enabled = cb.checked
    body.querySelectorAll(".stepper-btn").forEach(btn => {
      btn.disabled = !enabled
    })
  }

  // ── Steppers ───────────────────────────────────────────────────────────────

  increment(event) {
    this.#adjustQty(event.currentTarget.dataset.productId, 1)
  }

  decrement(event) {
    this.#adjustQty(event.currentTarget.dataset.productId, -1)
  }

  #adjustQty(productId, delta) {
    const valEl    = this.stepperValTargets.find(el => el.dataset.productId === productId)
    const hiddenEl = this.quantityTargets.find(el => el.dataset.productId === productId)
    if (!valEl || !hiddenEl) return

    const next    = Math.max(0, (parseInt(valEl.textContent, 10) || 0) + delta)
    valEl.textContent = next
    hiddenEl.value    = next
    this.#updateSubmit()
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  async #fetchLookup(phone, date) {
    let url = `${this.lookupUrlValue}?phone=${encodeURIComponent(phone)}`
    if (date) url += `&date=${encodeURIComponent(date)}`
    const resp = await fetch(url, {
      headers: { "Accept": "application/json", "X-Requested-With": "XMLHttpRequest" }
    })
    return resp.json()
  }

  async #fetchProducts(date) {
    const resp = await fetch(`/staff/orders/products?date=${encodeURIComponent(date)}`, {
      headers: { "X-Requested-With": "XMLHttpRequest" }
    })
    return resp.ok ? resp.text() : ""
  }

  #applyExistingReservation() {
    // Reset all quantities to zero first
    this.stepperValTargets.forEach(el => { el.textContent = "0" })
    this.quantityTargets.forEach(el => { el.value = "0" })

    const res = this._existingReservation
    if (!res) return

    // Pre-fill items
    Object.entries(res.items || {}).forEach(([productId, qty]) => {
      const valEl    = this.stepperValTargets.find(el => el.dataset.productId === productId)
      const hiddenEl = this.quantityTargets.find(el => el.dataset.productId === productId)
      if (valEl)    valEl.textContent = qty
      if (hiddenEl) hiddenEl.value = qty
    })

    // Expand any collapsible section that has a pre-filled quantity > 0
    this.collapsibleBodyTargets.forEach((body, idx) => {
      const hasQty = Array.from(body.querySelectorAll("[data-new-order-target='quantity']"))
        .some(el => parseInt(el.value, 10) > 0)
      if (!hasQty) return

      body.classList.remove("hidden")
      const head = this.collapsibleHeadTargets[idx]
      if (head) {
        const toggle = head.querySelector(".collapsible-toggle")
        if (toggle) toggle.textContent = "Hide"
      }
      const cb = body.querySelector(".override-cb")
      if (cb) {
        cb.checked = true
        body.querySelectorAll(".stepper-btn").forEach(btn => { btn.disabled = false })
      }
    })

    // Pre-fill pickup time
    if (this.hasPickupTimeTarget && res.pickup_time) {
      this.pickupTimeTarget.value = res.pickup_time
    }

    // Pre-fill note
    if (this.hasNoteTarget && res.note) {
      this.noteTarget.value = res.note
    }

    // Pre-fill source
    if (res.source && this.hasSourceTarget) {
      const radio = this.sourceTarget.querySelector(`input[value="${res.source}"]`)
      if (radio) radio.checked = true
    }
  }

  #updateSubmitLabel() {
    if (!this.hasSubmitTarget) return
    const isUpdate = !!this._existingReservation
    this.submitTarget.textContent = isUpdate
      ? this.submitTarget.dataset.updateLabel
      : this.submitTarget.dataset.confirmLabel
  }

  #buildTimeSlots(opensAt, closesAt) {
    if (!this.hasPickupTimeTarget) return
    const sel = this.pickupTimeTarget
    const prev = sel.value
    sel.innerHTML = '<option value=""></option>'
    if (!opensAt || !closesAt) return

    const [oh, om] = opensAt.split(":").map(Number)
    const [ch, cm] = closesAt.split(":").map(Number)
    const startMin = oh * 60 + om
    const endMin   = ch * 60 + cm

    for (let t = startMin; t <= endMin; t += 30) {
      const h   = Math.floor(t / 60)
      const m   = t % 60
      const val = `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`
      const ampm = h < 12 ? "AM" : "PM"
      const h12 = h % 12 || 12
      const label = `${h12}:${String(m).padStart(2, "0")} ${ampm}`
      const opt = document.createElement("option")
      opt.value = val
      opt.textContent = label
      if (val === prev) opt.selected = true
      sel.appendChild(opt)
    }
  }

  #showNameHint() {
    if (this.hasNameHintTarget) this.nameHintTarget.classList.remove("hidden")
  }

  #hideNameHint() {
    if (this.hasNameHintTarget) this.nameHintTarget.classList.add("hidden")
  }

  #updateSubmit(busy = false) {
    if (!this.hasSubmitTarget) return
    const hasPhone = this.phoneTarget.value.trim().length > 0
    const hasItem  = this.quantityTargets.some(el => parseInt(el.value, 10) > 0)
    this.submitTarget.disabled = busy || !hasPhone || !hasItem
  }
}

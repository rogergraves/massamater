# Massa Mater — Design Spec

**Date:** 2026-06-20
**Stack:** Ruby on Rails · SQLite · Fly.io
**Scope:** v1 — full app, staff + customer, no accounts/payments/messaging

---

## 1. Overview

Massa Mater is a reservation app for Padaria Massa Mater, a bakery. Customers reserve bread for pickup via a public self-service flow. Staff manage orders through a private day view and configure the app through a set of settings screens.

The app is bilingual (Portuguese / English). The customer-facing flow and staff interface both support a language toggle (PT | EN). The default language is Portuguese. The UI renders in the selected language at runtime using Rails i18n.

---

## 2. Users & Roles

| Role | Access | Auth |
|---|---|---|
| **Customer** | Public reservation flow only | None (no account) |
| **Staff** | All staff screens | Simple password-based login (no per-user accounts in v1) |

Staff and customers share the same `users` table, identified by phone number. Staff users have a `password_digest` set; logging in with a valid password grants access to the staff screens. Customer users have no enforced password — they are looked up or created by phone number when making a reservation.

---

## 3. Data Model

### `products`
| Column | Type | Notes |
|---|---|---|
| `id` | integer | |
| `name` | string | |
| `icon` | attachment | Active Storage — small icon used in lists |
| `photo` | attachment | Active Storage — full quality image, expandable in customer flow |
| `default_ready_time` | time | e.g. 09:00 — resets daily |
| `default_daily_batch_size` | integer | default quantity baked per day, used to pre-fill daily inventory |
| `max_reservable_quantity_per_client` | integer | nullable — cap on how many a single customer can reserve |
| `active` | boolean | whether shown to customers |
| `order` | integer | display sort order |
| `created_at` | datetime | |

### `product_schedule_days`
Which days of the week each product is normally baked.

| Column | Type | Notes |
|---|---|---|
| `id` | integer | |
| `product_id` | integer | FK → products |
| `day_of_week` | integer | 0=Sun … 6=Sat (Ruby convention) |

### `store_hours`
Weekly recurring schedule.

| Column | Type | Notes |
|---|---|---|
| `id` | integer | |
| `day_of_week` | integer | 0=Sun … 6=Sat |
| `open` | boolean | |
| `opens_at` | time | |
| `closes_at` | time | |

One row per day of week (7 rows total, seeded on setup).

### `store_exceptions`
One-off date overrides to the weekly schedule.

| Column | Type | Notes |
|---|---|---|
| `id` | integer | |
| `date` | date | the specific date |
| `closed` | boolean | true = fully closed |
| `opens_at` | time | nullable — used when `closed` is false |
| `closes_at` | time | nullable |
| `reason` | string | internal note (e.g. "Family emergency") |

### `daily_inventory`
Per-date overrides to product availability. Only rows that differ from the product default are stored.

| Column | Type | Notes |
|---|---|---|
| `id` | integer | |
| `product_id` | integer | FK → products |
| `date` | date | |
| `batch_size` | integer | how many are being baked today |
| `ready_time_override` | time | nullable — overrides `products.default_ready_time` |
| `skipped` | boolean | true = not available today despite normal schedule |
| `added` | boolean | true = available today despite not on normal schedule |

Effective ready time for a given product on a given date:
`daily_inventory.ready_time_override ?? products.default_ready_time`

### `users`
Represents both customers and staff. Phone number is the primary identifier.

| Column | Type | Notes |
|---|---|---|
| `id` | integer | |
| `phone` | string | normalized E.164, unique |
| `name` | string | |
| `contact_channel` | enum | `sms` / `whatsapp` |
| `password_digest` | string | nullable — set for staff; blank for customers in v1 |
| `created_at` | datetime | |

Authentication in v1 uses Rails' built-in `has_secure_password`, which bcrypt-hashes into `password_digest`. Staff access is granted by having a password set and presenting it correctly. Customer users have no password enforced — identified by phone number only.

**Future-proofing note:** `has_secure_password` uses the same bcrypt algorithm as Devise and Rodauth. Migrating to either later requires no re-hashing of existing passwords — only a column rename (`password_digest` → `encrypted_password` for Devise) and adding their supporting columns. Avoid any custom hashing scheme that would break this compatibility.

### `reservations`
| Column | Type | Notes |
|---|---|---|
| `id` | integer | |
| `user_id` | integer | FK → users |
| `date` | date | pickup date |
| `pickup_time` | time | customer's stated pickup time |
| `note` | text | optional customer note |
| `source` | enum | `online` / `sms` / `whatsapp` / `phone` / `counter` |
| `collected_at` | datetime | nullable — set when staff marks collected |
| `cancelled` | boolean | default false |
| `created_at` | datetime | |

### `reservation_items`
| Column | Type | Notes |
|---|---|---|
| `id` | integer | |
| `reservation_id` | integer | FK → reservations |
| `product_id` | integer | FK → products |
| `quantity` | integer | |

---

## 4. Screens

### 4.1 Customer — Self-Service Reservation Flow

> Mockup: [`../../mockups/customer-reservation-flow.html`](../../mockups/customer-reservation-flow.html)

Public, no login. Three-step wizard on mobile.

**Entry point**
The customer flow homepage offers two paths:
- **New reservation** — proceeds to the 3-step wizard
- **Manage my orders** — prompts for phone number, shows upcoming orders (see 4.7)

**Step 1 — Choose pickup day**
- Shows the next 7 calendar days (today + 6)
- Days where the store is closed (weekly schedule or exception) shown as "Closed" and unselectable
- Language toggle (PT | EN) in header throughout

**Step 2 — Choose items**
- Lists all active products scheduled for the selected day
- Products marked sold out (batch_size = 0 in daily_inventory) shown greyed with "Sold out" label
- Products with a late ready time show a note: "Available from HH:MM"
- Each product has a thumbnail (if photo uploaded); tapping expands an inline photo preview
- Quantity steppers (− / +); sold-out products disabled
- No prices shown

**Step 3 — Time & contact**
- Free time input (not fixed slots); minimum time is floored to the latest `effective_ready_time` across all items in the cart
- Hint text explains why the minimum exists if it's not opening time (e.g. "Earliest: 11:00 — cinnamon rolls not ready until 11:00")
- Name field (required)
- Phone number field (required)
- Contact method toggle: SMS | WhatsApp
- Optional note field
- Summary shows items and pickup time before confirming
- On submit: creates `reservation` + `reservation_items`, redirects to a confirmation page with order summary

---

### 4.2 Staff — Day View

> Mockup: [`../../mockups/staff-day-view.html`](../../mockups/staff-day-view.html)

Landscape tablet layout. The primary daily working screen.

**Top bar**
- Day picker: shows next 7 days with open days selectable; closed days shown but unselectable
- PT | EN language toggle
- "+ New order" button → opens the new order form (see 4.5)

**Inventory tally bar**
- One chip per product active today: `Product name — X collected / Y batch (Z remaining)`
- Products nearing zero shown with an amber tint
- Sold-out products shown in red
- Products with a today override on ready time show a warning indicator (⚠) with the overridden time

**Order grid**
- Cards in a 3-column grid, sorted by pickup time ascending; collected orders sorted to the bottom
- Cancelled orders are hidden entirely — not shown, not counted
- Each card shows: customer name, contact (phone number), items + quantities, pickup time, order source badge (ONLINE / SMS / WHATSAPP / PHONE / COUNTER), optional customer note
- Tapping a card marks it as collected (greyed out, strikethrough, sorted to bottom); tapping again restores it
- Each card has a menu (⋯) with actions: **Edit order** and **Cancel order**. Cancel prompts for confirmation; confirmed cancellations disappear immediately.
- **Conflict cards:** When a product's effective ready time is later than the customer's pickup time, the card gets an amber border and a conflict flag ("Cinnamon rolls ready at 11:30"). The phone number on a conflict card is a tappable link that opens SMS (`sms:`) or WhatsApp (`wa.me`) depending on the customer's `contact_channel`

---

### 4.3 Staff — Daily Inventory

> Mockup: [`../../mockups/staff-daily-inventory.html`](../../mockups/staff-daily-inventory.html)

Accessed from a settings/nav area. One screen per day (defaults to today).

- Lists only products scheduled for the selected day (via `product_schedule_days`) plus any manually added today
- **Default ready time column:** from `products.default_ready_time` — editable here (saves to `products`, permanent)
- **Today's override column:** editable, saves to `daily_inventory.ready_time_override` for that date only — resets tomorrow. Shown in orange when set. Conflict badge appears inline if any orders are affected.
- **Batch size column:** saves to `daily_inventory.batch_size`
- **Status column:** Scheduled / Ready late / Added / Skipped
- **Skip button:** marks `daily_inventory.skipped = true` for today — product disappears from customer flow
- **Restore button:** on skipped rows, reverses the skip
- **Add for today dropdown:** shows products not on today's normal schedule; selecting one creates a `daily_inventory` row with `added = true`
- Alert banner at top when any conflict exists: "X orders affected — customers arriving before their items are ready"

---

### 4.4 Staff — Product Catalog

> Mockup: [`../../mockups/staff-product-catalog.html`](../../mockups/staff-product-catalog.html)

Permanent product settings.

- List of all products with inline expand per row
- Collapsed row shows: icon (read-only), name, day-of-week pills (coloured = active), chevron
- Expanded row shows:
  - Day-of-week checkboxes (Mon–Sun); store-closed days greyed out and unselectable
  - Default ready time input
  - Default batch size input
  - Max per customer input
  - Active toggle
  - Photo upload (Active Storage; replaces existing if already set)
  - Icon display (read-only — generated offline via the icon generator tool; see companion doc)
  - Name fields (PT and EN) — if only one language is entered, the other falls back to the set value at runtime
- "+ New product" button adds a blank row in edit mode
- Delete button (with confirmation) — prevents deletion if product has future reservations; deactivate instead

**Icons** are not uploaded by staff. They are generated offline using the icon generator script ([`docs/tools/icon-generator.md`](../../tools/icon-generator.md)), which sends each product photo to the OpenAI image generation API with a fixed style prompt to produce a consistent icon set, then uploads the results to the Fly.io server.

---

### 4.5 Staff — New Order Form

> Mockup: [`../../mockups/staff-new-order.html`](../../mockups/staff-new-order.html)

Used for walk-in, phone, and staff-entered orders.

- Phone number (required) — shown first; on entry, looks up the `users` table and auto-fills customer name and preferred contact if a matching record exists
- Customer name (required)
- Contact method: SMS | WhatsApp
- Pickup date (required) — defaults to today; selectable within the 7-day window
- Pickup time (optional) — shown alongside date; defaults to blank; staff leave it empty if the customer hasn't specified
- Order source: PHONE / SMS / WHATSAPP / COUNTER
- Item selection: checkboxes + quantity inputs for products scheduled on the selected date (updates when date changes); each item shows remaining stock (batch size minus already reserved quantities). Items at zero show "Fully reserved · 0 remaining" but remain selectable — staff can override and enter any quantity, with the expectation they adjust batch size in Daily Inventory if needed
- Optional note — no placeholder; used at staff discretion
- On save: creates reservation with `source` set to the selected channel; updates the matching `users` record if name or contact method has changed

---

### 4.6 Staff — Store Hours

> Mockup: [`../../mockups/staff-store-hours.html`](../../mockups/staff-store-hours.html)

Two sections:

**Weekly schedule**
- One row per day of week (Mon–Sun)
- Toggle open/closed; when closed, time inputs are disabled and greyed
- Opens at / closes at time inputs
- Saves to `store_hours`

**One-off exceptions**
- List of upcoming exceptions (past exceptions hidden)
- Each row: date, day of week, reason, status (Closed or alternative hours)
- Delete button per exception
- Add form: date picker, reason text field, type toggle (Closed | Different hours); when "Different hours" selected, time inputs appear
- Saves to `store_exceptions`

**Reservation window note**
- Informational strip: "Reservations accepted up to 7 days ahead. Closed days don't appear in the reservation form."
- The 7-day window is hardcoded in v1

---

### 4.7 Customer — Manage My Orders

> Mockup: [`../../mockups/customer-manage-orders.html`](../../mockups/customer-manage-orders.html)

Public, no login. Accessed from the customer flow homepage.

- Customer enters their phone number and taps **Continue**
- If no matching user exists or they have no reservations, redirect directly to the new reservation flow
- If found, show upcoming and past reservations for that phone number, sorted by date + pickup time
- Each reservation shows: date, pickup time, items summary, status
- Upcoming reservations (not yet collected) have two actions:
  - **Edit** — opens an edit form pre-filled with existing values; customer can change pickup time, items, contact channel, or note. Pickup time minimum is re-validated against effective ready times. On save, updates the reservation in place.
  - **Cancel** — prompts "Are you sure?"; on confirm, sets `cancelled = true`. Reservation disappears from this list.
- Collected reservations show a **Repeat this order** button — pre-fills a new reservation with the same items, ready for the customer to choose a new date and time. Only the 2 most recent collected reservations are shown (most recent first) to keep the list manageable
- A **New reservation** button is always visible at the bottom of the list

---

### 4.8 Staff — Edit Order

> Mockup: [`../../mockups/staff-edit-order.html`](../../mockups/staff-edit-order.html)

Accessed from the ⋯ menu on a day view card, or from a per-customer order list.

- Pre-filled form identical in structure to the New Order form (4.5)
- All fields editable: customer name, phone, contact channel, pickup time, source, items, note
- If phone number is changed to one matching an existing user, the reservation is re-linked to that user
- If phone number is changed to a new number, a new user record is created
- Save updates the reservation in place; the day view card reflects changes immediately
- **Cancel order** button at the bottom of the form — prompts for confirmation; on confirm sets `cancelled = true` and returns to day view

Staff can also browse orders by customer: searching by name or phone number shows all reservations for that user across all dates, with the same edit/cancel actions.

---

## 5. Business Rules

### Cancellation
- Either the customer or staff may cancel a reservation at any time until `collected_at` is set
- Setting `cancelled = true` causes the reservation to be excluded from all views, tallies, inventory counts, and conflict checks — it behaves as if it never existed
- Cancellation is not reversible in v1

### Availability on a given date
A product is available for reservation on a given date if ALL of the following are true:
1. `products.active = true`
2. The date's day-of-week is in `product_schedule_days` for that product, OR `daily_inventory.added = true` for that date
3. `daily_inventory.skipped` is not true for that date
4. `daily_inventory.batch_size > 0` (if a row exists for that date; if no row, treat as available)

### Effective ready time
```
effective_ready_time(product, date) =
  daily_inventory.ready_time_override (if row exists and override is set)
  ?? products.default_ready_time
```

### Minimum pickup time (customer flow)
```
min_pickup_time(cart, date) =
  max(effective_ready_time(p, date) for each product p in cart)
```
If this equals the store's opening time, no hint is shown. Otherwise, the hint names the constraining product(s).

### Conflict detection
A reservation has a conflict if any item in the order has:
```
effective_ready_time(product, reservation.date) > reservation.pickup_time
```
Conflicts are detected and displayed in real time when a daily override is saved. They are also shown persistently on the day view until the customer's pickup time passes or the conflict is resolved.

### Store open/closed on a date
```
store_open?(date) =
  store_exceptions.find_by(date: date)&.closed == false  →  use exception hours
  store_exceptions.find_by(date: date)&.closed == true   →  closed
  store_hours.find_by(day_of_week: date.wday)&.open      →  use weekly hours
  default                                                 →  closed
```

### Reservation window
Customers may only reserve for dates where:
- The store is open (per above)
- The date is between tomorrow and 7 days from today (inclusive)
- Today is excluded — same-day reservations not supported in v1

---

## 6. Navigation (Staff)

Simple top-level nav with four items:

| Label | Screen |
|---|---|
| Today | Day view (defaults to today) |
| Inventory | Daily inventory (defaults to today) |
| Products | Product catalog |
| Settings | Store hours |

---

## 7. i18n

- All UI strings are defined in `config/locales/en.yml` and `config/locales/pt.yml`
- Product names are a single `name` field — staff enter them in whichever language they prefer; no automatic translation
- Both interfaces default to Portuguese; language preference stored in the session via the PT | EN toggle

---

## 8. Out of Scope (v1)

- Customer accounts or login
- Payment processing (pay at counter)
- App-initiated SMS or WhatsApp messages (tap-to-open links only)
- Push or email notifications
- Multiple bakery locations
- Reporting or analytics
- Per-user staff accounts

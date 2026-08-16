# Staff Day View Spec

## Overview

The "Today" nav link currently shows a placeholder dashboard. This spec defines what it should actually show: a single-date operational view that gives staff a complete picture of the day — what products are available, how many are reserved, and the full list of customer reservations.

---

## URL / Route

`GET /staff` (existing `staff_root_path`, handled by `Staff::DashboardController#index`)

No new routes needed.

---

## Page layout

```
┌─────────────────────────────────────────────────┐
│  Today — Saturday, Jul 19                       │
├─────────────────────────────────────────────────┤
│  PRODUCTS                                       │
│  ┌───────────────────────────────────────────┐  │
│  │ Sourdough     Ready 9:00   20 / 50  [░░░] │  │
│  │ Baguette      Ready 9:00    8 / 20  [░░░] │  │
│  │ Corn Bread    SKIPPED                     │  │
│  └───────────────────────────────────────────┘  │
├─────────────────────────────────────────────────┤
│  RESERVATIONS  (12 orders · 28 items)           │
│  ┌───────────────────────────────────────────┐  │
│  │ 09:00  Ana Silva     Sourdough ×2         │  │
│  │        (no pickup time)  Baguette ×1      │  │
│  │ 09:30  João Costa    Sourdough ×1         │  │
│  │ ...                                       │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

---

## Part 1: Page header

- Title: "Today — {full weekday name}, {Month} {day}" e.g. "Today — Saturday, Jul 19"
- Uses `Date.current` — always shows today's date

---

## Part 2: Products section

Shows only products that are **available today** — meaning:
- Product is active
- Product is scheduled for today's day-of-week (`product_schedule_days`)
- Product does NOT have a Skip exception for today
- OR product has an Add exception for today (not normally scheduled but added)

For each available product, show a row with:

| Field | Source |
|---|---|
| Photo (thumbnail) | `product.photo` (if attached) |
| Name | `product.display_name` |
| Ready time | `effective_ready_time` from exception if override exists, else `product.default_ready_time` |
| Reserved / Total | reserved count / effective batch size |
| Progress bar | visual fill: reserved ÷ effective batch size |

**Effective batch size** — the quantity available today:
- If a Skip exception exists → product not shown (skipped)
- If an Override exception with `batch_size` exists → use that
- If an Add exception exists → use its `batch_size`
- Otherwise → use `product.default_daily_batch_size`

**Reserved count** — sum of `reservation_items.quantity` for today's active (non-cancelled) reservations for that product.

**Progress bar** — a simple horizontal bar showing reserved/total. Turns a warning color (amber) when ≥ 75% full, danger color (red) when 100% full or over.

**Skipped products** — products with a Skip exception for today are not shown at all.

---

## Part 3: Reservations section

Shows active, uncollected, non-cancelled reservations for today, sorted by pickup time (no pickup time shown last). Collected reservations are not shown.

Section header shows total order count and total item count: "12 orders · 28 items"

Each reservation row shows:
- Pickup time (e.g. "09:00") or blank if no pickup time set
- Customer name
- Items: one line per product — product name and quantity (e.g. "Sourdough ×2")

### New reservation button

A **"+ New reservation"** button appears in the section header. It links to the new reservation flow (a separate feature — not built here), pre-seeded with today's date and `source: :counter` or `source: :phone`. For now the button exists but links to `#` as a placeholder — the actual flow is built in a future feature.

---

## What stays the same

- The "Today" nav link already exists and points to `staff_root_path`
- `Staff::DashboardController` and its route already exist — only the `index` action and view need to change

---

## What this does NOT include (out of scope)

- Marking a reservation as collected (separate feature)
- Cancelling a reservation (separate feature)
- Navigating to other dates (always shows today only)
- The new reservation form itself (separate feature — button links to `#` for now)

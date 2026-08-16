# Inventory Section Spec

## Overview

A single "Inventory" page combining the product catalog and date-specific exceptions, following the same two-part pattern as Store Hours:

- **Top part: Products** — the standing defaults (what you normally offer, which days, default batch sizes and ready times).
- **Bottom part: Exceptions** — date-specific overrides for when a specific day differs from the default.

---

## Nav

The nav link currently labeled "Products" becomes "Inventory". No separate Daily Inventory nav link.

---

## Route / URL

Replaces `/staff/products`. New route: `GET /staff/inventory`.

---

## Page layout

```
┌─────────────────────────────────────────────┐
│  Inventory                                  │
│  Manage products and daily exceptions       │
├─────────────────────────────────────────────┤
│  PRODUCTS                                   │
│  Your default daily offerings               │
│  ┌──────────────────────────────────────┐   │
│  │ [photo] Baguette   Mon Wed Fri  20   │   │
│  │ [photo] Croissant  Tue Thu      12   │   │
│  │  ⋮  (inline edit per row)           │   │
│  └──────────────────────────────────────┘   │
├─────────────────────────────────────────────┤
│  EXCEPTIONS                                 │
│  Override products on specific dates        │
│  ┌──────────────────────────────────────┐   │
│  │ Today, Jul 19  Baguette  Skip  [×]   │   │
│  │ Jul 22         Croissant  qty 30 [×] │   │
│  │ Jul 25         Brioche   Added  [×]  │   │
│  │ [date] [product▾] [type▾] [fields] [Add] │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

---

## Part 1: Products (defaults)

Same as the current Product Catalog, unchanged in behavior:

- Each product row: thumbnail photo, name, day chips, default batch size
- Clicking a row expands an inline edit form with its own **Save** button (per-product, not global):
  - Name
  - Default batch size
  - Default ready time
  - Day-of-week checkboxes
  - Photo upload
  - Save / Delete buttons
- "+ Add product" at the bottom opens an inline add form with the same fields

---

## Part 2: Exceptions

### Existing exceptions list

Sort order: today's exceptions first, then future dates ascending. Past exceptions (before today) are not shown.

Each exception row shows:
- Date — shown as "Today, Jul 19" if today, otherwise "Jul 22, Wed"
- Product name
- Summary label: "Skipped", "Qty: 30", "Ready: 10:30", "Qty: 8, Ready: 10:30", or "Added (qty: 8)"
- A **×** delete button — immediate DELETE, no confirmation, same as store hours exceptions

### Add exception form (inline, always visible at the bottom)

Fields:

1. **Date** — date input, min: today
2. **Product** — select of all active products
3. **Type** — radio buttons (same style as store hours):
   - **Skip** — product won't be available that day (no further fields)
   - **Override** — change one or more of: qty, ready time (both fields shown, both optional — save whatever is filled in)
   - **Add** — offer a product on a day it's not normally scheduled (qty field shown, ready time hidden)
4. **Qty** field — shown for Override and Add (hidden for Skip)
5. **Ready time** field — shown for Override only

An **Add** button submits the form and adds the exception immediately, staying on the page.

Validation errors shown inline below the form.

### Data mapping to `daily_inventories` table

| Type | `skipped` | `added` | `batch_size` | `ready_time_override` |
|---|---|---|---|---|
| Skip | true | false | null | null |
| Override | false | false | new qty or null | new time or null |
| Add | false | true | new qty (required) | null |

---

## What changes from current code

- `Staff::ProductsController` → `Staff::InventoryController`
- `/staff/products` → `/staff/inventory`
- Nav "Products" → "Inventory"
- `DailyInventory` records are created only via the Exceptions form
- No separate Daily Inventory controller, view, route, or nav link

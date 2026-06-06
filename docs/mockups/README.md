# Massa Mater — UI Mockups

Brainstorming mockups for the Padaria Massa Mater reservation app. These are static
HTML mockups produced with the Superpowers visual brainstorming companion. They are
**committed** (unlike the throwaway `.superpowers/brainstorm/` working copies) so we
can recall and iterate on specific screens in later sessions.

## Files

| File | Screen | Notes |
|------|--------|-------|
| `staff-day-view.html` | Staff "day sheet" (landscape tablet) | Day picker, PT/EN toggle, "+ Nova encomenda", inventory tally bar ("Fornada de hoje"), 3-per-row order grid. Tap a card → collected (greys out, sorted to the bottom). Source tags: ONLINE / SMS / WHATSAPP / TELEFONE / BALCÃO. |
| `customer-reservation-flow.html` | Customer self-service flow (mobile) | 3 steps: choose pickup day → choose items (sold-out greyed, no counts) → time slots + contact + optional note → confirm. Shows prices + total to pay at counter (pending owner confirmation). |
| `entry-channels.html` | Order-source examples (landscape) | One example card per entry channel + a fulfilled/greyed example. Superseded by `staff-day-view.html` but kept for reference. |

## How to view / iterate later

1. Open any file directly in a browser, **or**
2. Re-launch the visual companion and copy the file(s) into its content dir:
   ```bash
   # from the superpowers brainstorming skill dir:
   scripts/start-server.sh --project-dir /Users/rogergraves/workspace/massamater
   # then copy a mockup into the printed screen_dir to serve it
   ```

## Open design questions captured in these mockups

- Show **prices** publicly to customers? (adds price field per item)
- Pickup time as **fixed slots** vs "anytime after X"
- Customer item view: **prominent photos** vs compact list
- "Rolos de canela" vs "cinnamon rolls" as the item's PT name

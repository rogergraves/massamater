# Icon Generator

Generates consistent product icons from product photos using the OpenAI image generation API, then uploads them to the Fly.io server via a Rails task.

---

## How it works

1. You run a Rails task locally.
2. For each product that has a photo but no icon, the task downloads the product photo and sends it to OpenAI's `gpt-image-1` model with a fixed style prompt. If any icons have already been generated in previous runs, one is included as a visual style reference to ensure consistency.
3. You review the icons locally (they are saved to `tmp/icons/`).
4. You run a second task to upload the approved icons to the remote server.

---

## Prerequisites

- OpenAI API key with access to `gpt-image-1`
- Local Rails environment pointing at the production database (or a seed with the same products)
- Fly.io CLI installed and authenticated (`fly auth login`)

Add your OpenAI key to your local credentials or `.env`:

```
OPENAI_API_KEY=sk-...
```

---

## Step 1 — Generate icons locally

```bash
bin/rails icons:generate
```

This task:
- Queries all active products where `icon` is not attached
- For each product, downloads the attached `photo` to a temp file
- Sends it to the OpenAI API with the style prompt below
- Saves the result to `tmp/icons/<product-id>-<slug>.png`

**Style prompt used:**

```
A flat vector-style illustration icon of [product name]. Single centred subject,
no text, no background clutter. Warm cream background (#f9f6f1). Earthy brown
and terracotta palette consistent with an artisan bakery brand. Clean outlines,
simple shapes. Square format, suitable for use as a small app icon.
```

The product photo is always passed as an image input so the model can match the actual appearance of the item.

**Style reference (subsequent runs only):** If `tmp/icons/` already contains icons from a previous run, the task picks one at random and includes it as an additional image input with the instruction: *"Match the illustration style, line weight, background colour, and palette of this existing icon exactly."* This anchors the style across separate generation runs, even if the model has been updated in the meantime.

On the very first run there are no reference icons, so the style prompt alone sets the standard. Keep at least one icon from the first batch in `tmp/icons/` permanently as the style anchor — do not delete the whole folder after uploading.

Generated files land in `tmp/icons/`. Review them before uploading — regenerate any that look wrong by deleting that file and re-running the task (the task skips products whose icon file already exists in `tmp/icons/`).

To force-regenerate a specific product:

```bash
bin/rails icons:generate PRODUCT_ID=42
```

---

## Step 2 — Review icons locally

Open `tmp/icons/` in Finder and inspect each PNG. They should:
- Have a cream/off-white background matching the app palette
- Show a single, clearly recognisable illustration of the product
- Be visually consistent across all products (same style, same weight)

If any look off, delete that file and re-run the task for that product ID.

---

## Step 3 — Upload icons to the remote server

Once you are happy with the icons locally, run:

```bash
bin/rails icons:upload
```

This task:
- Reads each PNG from `tmp/icons/`
- Connects to the running Rails app on Fly.io via `fly ssh console`
- Attaches each file to the corresponding product's `icon` attachment via Active Storage
- Reports success or failure per product

Alternatively, you can run the upload directly on the Fly.io machine:

```bash
# Copy icon files to the Fly.io volume
fly sftp shell
put tmp/icons/* /app/tmp/icons/

# Then run the upload task remotely
fly ssh console -C "bin/rails icons:attach_from_tmp"
```

The `icons:attach_from_tmp` task reads from `/app/tmp/icons/` on the remote machine and attaches the files.

---

## Rake task location

The tasks will be implemented in `lib/tasks/icons.rake`. See the implementation plan for the full task code.

---

## Re-running after adding new products

When new products are added to the app:

1. Upload a product photo via the staff Product Catalog screen.
2. Ensure `tmp/icons/` still contains at least one icon from the original batch (the style anchor).
3. Run `bin/rails icons:generate` locally — it skips products that already have an icon file in `tmp/icons/` and only generates new ones. The existing icon is automatically used as a style reference.
4. Review and run `bin/rails icons:upload`.

---

## Notes

- Icons are stored via Active Storage, the same as product photos. On Fly.io, Active Storage is configured to use the local disk on the persistent volume (`/data`).
- The `gpt-image-1` model produces 1024×1024 PNGs by default. The app displays icons at much smaller sizes (36–52px), so the resolution is more than sufficient.
- OpenAI charges per generated image. At the time of writing, `gpt-image-1` standard quality is ~$0.04 per image. A catalog of 20 products costs under $1 to generate.

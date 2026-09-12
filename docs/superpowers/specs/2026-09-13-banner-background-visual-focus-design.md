# Dynamic Banner Background Visual Focus Design

## Background

Admin users can create dynamic operation banners and upload images, but the Flutter home banner currently renders the image only in the right 40% of the card. The rest of the card remains a gradient. This wastes the uploaded visual and prevents the operator from choosing which part of the image is shown.

## Goals

- Render an operation banner image as the full-bleed background of the home banner.
- Let an admin choose the image's visible area from a preview that matches the app banner shape.
- Preserve the old behavior when a banner has no image or no focus metadata.
- Keep text readable on every UI style and theme by using only the permitted translucent photo overlay.

## Non-Goals

- Do not crop, overwrite, or generate a new stored image.
- Do not change banner routing, exposure tracking, conditions, ordering, or activation behavior.
- Do not change other banner types that use template covers.

## Data Design

Add nullable metadata to `operation_banners`:

| Column       | Type     | Range / Meaning                              | Default |
| ------------ | -------- | -------------------------------------------- | ------- |
| `focus_x`    | `double` | Horizontal focus, `0` = left, `1` = right    | `0.5`   |
| `focus_y`    | `double` | Vertical focus, `0` = top, `1` = bottom      | `0.5`   |
| `focus_zoom` | `double` | Background image zoom, `1`–`3`               | `1.0`   |

Admin API payload accepts `focusX`, `focusY`, and `focusZoom`. The App API returns the same values in camelCase. Missing or invalid values fall back to `0.5 / 0.5 / 1.0`.

## Admin Experience

The image field adds a banner-shaped preview below upload controls. The preview:

- Uses the same full-width, 150-pt logical height proportions as the app card.
- Fills the preview with `cover` plus the selected zoom.
- Shows a draggable focus marker on the image.
- Uses a slider for zoom from 1x to 3x.
- Shows live text overlay so the operator can judge readability.

Saving stores the selected focus values with the image URL. Removing an image does not necessarily clear focus metadata, so values remain reusable when a new image is uploaded. The values are always validated and clamped server-side.

## Flutter Experience

For a remote operation banner with `imageUrl`:

- The image is the full-card background using `BoxFit.cover`.
- The focus values map to Flutter's image `Alignment` value.
- The zoom maps to a background-image transform while preserving full-card coverage.
- A translucent dark gradient covers the photo for text readability; no theme-specific visual language is introduced.
- The text column spans the full card, and the arrow control remains photo-overlay UI.

For static or legacy operation banners without focus metadata, the app centers the image. Banners without an image continue using the existing gradient placeholder.

## Compatibility

- Existing database rows are nullable-safe and receive app-level defaults before the metadata is edited.
- Older App versions ignore the new API fields and continue rendering their current right-side image layout.
- The Redis banner-list cache is invalidated by the existing write path.

## Verification

- Backend: DTO/service tests cover clamping, defaults, create/update, and App list output.
- Admin: build/lint verification covers the focus preview and payload mapping.
- Flutter: unit tests parse defaults, valid focus metadata, and invalid fallback values.
- Flutter UI: analyze and tests verify full-bleed rendering, focus alignment, zoom, and readability overlay.

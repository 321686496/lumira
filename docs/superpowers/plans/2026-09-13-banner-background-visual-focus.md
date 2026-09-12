# Dynamic Banner Background Visual Focus Implementation Plan



Goal: Render operation banner images as full-card backgrounds and let admins tune focus and zoom.

**Goal:** Render operation banner images as full-card backgrounds and let admins tune focus and zoom.

**Architecture:** Add three nullable focus columns to `operation_banners`, pass them through backend DTOs and App list responses, and persist them from the admin Banner dialog. Flutter maps the values to a transformed `BoxFit.cover` background with the existing translucent readability overlay.

**Tech Stack:** NestJS + Drizzle + MySQL 8, Next.js admin, Flutter/Riverpod (Dart 2.19), Jest, flutter_test.

## Global Constraints

- Focus ranges: `focusX` and `focusY` are 0–1; `focusZoom` is 1–3.
- Missing or invalid metadata defaults to `focusX = 0.5`, `focusY = 0.5`, `focusZoom = 1.0`.
- Do not crop or replace the uploaded image; preserve the original asset.
- Flutter UI must derive non-photo theme visuals from `appThemeProvider`; only the photo readability overlay may use black translucency.
- Dart code must remain compatible with Dart 2.19.6; no Dart 3 records.
- Backend/admin code changes are committed and pushed to `origin master` and `github master` immediately after each relevant task.

---

### Task 1: Backend Focus Persistence

**Files:**
- Modify: `lumira-server/packages/backend/src/database/schema.ts`
- Create: `lumira-server/packages/backend/src/database/migrations/035_banner_focus.sql`
- Modify: `lumira-server/packages/backend/src/modules/banners/dto/create-banner.dto.ts`
- Modify: `lumira-server/packages/backend/src/modules/banners/dto/update-banner.dto.ts`
- Modify: `lumira-server/packages/backend/src/modules/banners/banners.service.ts`
- Test: `lumira-server/packages/backend/src/modules/banners/banners.service.spec.ts`

**Interfaces:**
- Consumes: existing `BannersService.create/update/listForApp` and Drizzle schema.
- Produces: `focusX`, `focusY`, and `focusZoom` in admin records and App JSON; service clamps metadata before writes.

- [x] Write failing service tests for create, update, and App list mapping. Invalid values must be clamped; omitted values default to `0.5 / 0.5 / 1.0`.
- [x] Add three nullable `doublePrecision` fields to the schema and migration `035_banner_focus.sql`:
  `focus_x DOUBLE NULL`, `focus_y DOUBLE NULL`, `focus_zoom DOUBLE NULL`.
- [x] Add `@IsNumber()` + `@Min/@Max` DTO fields.
- [x] Insert and update all three fields, always returning stable normalized values.
- [x] Run `pnpm --filter @lumira/backend test -- banners.service.spec`.
- [x] Commit `feat: add banner image focus metadata`, then push both remotes.

### Task 2: Admin Visual Focus Editor

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`
- Modify: `lumira-server/packages/admin/src/components/banner-manager.tsx`
- Test/Verify: Admin build/typecheck workflow.

**Interfaces:**
- Consumes: backend `focusX`, `focusY`, `focusZoom` and `BannerPayload`.
- Produces: form state with validated focus values and a live Banner-shaped preview.

- [x] Extend `BannerAdminItem` and `BannerPayload` with optional numeric focus fields.
- [x] Add focus state to the form, initialize from the edited banner, and include it in the save payload.
- [x] Implement a preview using the uploaded object URL or existing image URL; make it Banner-shaped, draggable, and show a focus marker.
- [x] Add a 1x–3x zoom slider and live text overlay preview.
- [x] Run the admin build/typecheck and manually inspect the editor layout.
- [x] Commit `feat: add banner visual focus editor`, then push both remotes.

### Task 3: Flutter Model Parsing

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/data/operation_banners.dart`
- Modify: `lumira_app_flutter/lib/features/home/data/home_mock_data.dart`
- Test: `lumira_app_flutter/test/features/home/operation_banners_test.dart`

**Interfaces:**
- Consumes: backend App response fields `focusX`, `focusY`, `focusZoom`.
- Produces: `OperationBanner.focusX`, `focusY`, `focusZoom` and `HomeBannerItem` focus fields.

- [x] Write parser tests for omitted fields, valid fields, and out-of-range/invalid fields.
- [x] Add model fields and `clamp` normalization while parsing JSON.
- [x] Map operation models into `HomeBannerItem` without changing recommendation banners.
- [x] Run targeted Flutter tests for operation banners.
- [x] Commit `feat: parse banner focus metadata`.

### Task 4: Flutter Full-Bleed Rendering

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/widgets/home_banner.dart`
- Test: `lumira_app_flutter/test/features/home/home_page_test.dart`

**Interfaces:**
- Consumes: `HomeBannerItem` focus fields.
- Produces: operation image rendered as full-card transformed background.

- [x] Add a widget test asserting operation banners render image-backed full-bleed cards instead of the right-side split.
- [x] Replace the operation `Row` split with a background image using `BoxFit.cover`.
- [x] Apply focus alignment and zoom via a background transform while retaining rounded clipping.
- [x] Add the existing dark translucent gradient over the image and restore full-width text.
- [x] Run `flutter test` and `flutter analyze`.
- [x] Commit `feat: render focused banner backgrounds`.

### Task 5: Final Verification

**Files:**
- No planned implementation changes.

- [x] Run backend targeted tests, admin build/typecheck, Flutter analyze and tests.
- [x] Review `git diff` for unrelated changes and ensure no `lumira-app/` files were touched.
- [x] Commit any documentation-only updates separately if needed.

- [x] Summarize commands, results, and any follow-up optimization registration.

# Arua City Finder — Project Brief & Copilot Instructions

> Save this file in your repo as `.github/copilot-instructions.md`. Copilot reads it automatically in VS Code / GitHub. Keep it up to date as decisions change.

---

## 1. Product Overview

**Arua City Finder** is a localized, multi-vendor marketplace for **Arua City, Uganda**. It connects:

- **Tenants / Buyers** looking for rental properties and local services.
- **Landlords** listing properties for rent.
- **Service Providers** (plumbers, electricians, cleaners, movers, etc.) listing services.

Core value: *find a trusted, verified property or service in Arua quickly, contact the owner directly, and pay safely.*

**Targets:** Android (APK) and Web (PWA). Primary users are on mid/low-range Android phones with **unstable, expensive mobile data**, so performance and small downloads matter more than fancy visuals.

**Local context to respect**
- Currency: **UGX**, no decimals. Format as `UGX 350,000`. Never use `double` for money; use `int`.
- Many users prefer **phone call / WhatsApp** over in-app chat. Every listing should offer Call, WhatsApp, and In-app Chat buttons.
- Locations are Arua's divisions/wards/areas (e.g. Arua Hill, Oli, Ayivu, River Oli, Pajulu, etc.), stored as a controlled list, not free text.
- Phone numbers use `+256` format, validated and normalized before saving.

---

## 2. Tech Stack

| Layer | Choice | Notes |
|---|---|---|
| Frontend | Flutter (stable channel) / Dart 3, null-safety | Android + Web (PWA) |
| Auth | Firebase Auth | Email/password now; add **phone OTP** later (very common in Uganda) |
| Database | Cloud Firestore | Real-time + paginated queries |
| Media | Firebase Storage | Images compressed client-side; videos size-limited |
| Server logic | **Firebase Cloud Functions (TypeScript)** | Required for payments, role claims, rating aggregation, notifications |
| Payments | Flutterwave (UGX, MTN/Airtel Mobile Money, cards) | **Verified server-side only** (see §8) |
| Push | Firebase Cloud Messaging | Chat messages, listing approval status |
| State mgmt | **Riverpod** (`flutter_riverpod`) | Replaces raw `setState` for anything shared across screens |
| Images | `cached_network_image`, `flutter_image_compress` | |
| Security | **Firebase App Check** + strict Security Rules | |

> **Change from the original brief:** `setState` + `StreamBuilder` alone does not scale once chat, auth state, listings, and payments share data. Use Riverpod for app/feature state; `setState` is fine only for purely local widget state (form toggles, animations).
>
> **Billing note:** Cloud Functions (and, for newer projects, Firebase Storage) require the **Blaze (pay-as-you-go)** plan. It has a free tier, but a billing account must be attached. Set a budget alert.

---

## 3. Roles & Access Control

Roles: `tenant` (default), `landlord`, `provider`, `admin`.

**Critical security rules (the original design got these wrong):**

1. **The client must never be able to choose or change its own privileged role.** Registration UI may let a user say "I want to list properties/services", but this creates `role: 'tenant'` plus `roleRequest: 'landlord' | 'provider'`. An admin approves it, which sets the role.
2. **Admin is assigned only via Firebase Admin SDK as a custom claim** (`request.auth.token.admin == true`), set from a trusted script or Cloud Function. Not by editing a field a user could write.
3. **Role checks in the UI are for UX only.** Real enforcement is in **Firestore & Storage Security Rules** and Cloud Functions.
4. A user may only read/write **their own** `users/{uid}` document and may **not** modify `role`, `isVerified`, `ratingAvg`, or `ratingCount`.

| Capability | Tenant | Landlord/Provider | Admin |
|---|---|---|---|
| Browse approved listings | ✅ | ✅ | ✅ |
| Chat, favorite, rate | ✅ | ✅ | ✅ |
| Create/edit/delete **own** listings | ❌ | ✅ (new/edited → `pending`) | ✅ |
| Approve/reject/delete any listing | ❌ | ❌ | ✅ |
| Approve role requests, view stats | ❌ | ❌ | ✅ |

---

## 4. Features (MVP → Later)

### MVP (build in this order)
1. **Auth & roles** — register, login, logout, password reset, role-request flow, `AuthGate`/router.
2. **Browse (Jumia-style)** — search bar, category chips, 2-column grid, pagination (infinite scroll, 20 per page), pull-to-refresh, empty/error/loading states, listing detail page.
3. **Provider dashboard** — own listings with status badges (`Live`, `Pending`, `Rejected` with reason), edit, delete, FAB to add.
4. **Upload listing** — multi-image (max 8, compressed), optional short video (max ~30–50 MB, with thumbnail), form validation.
5. **Admin dashboard** — pending queue, approve/reject (with reason), delete, role-request approvals, basic counts.
6. **Contact** — Call, WhatsApp deep link, in-app chat.
7. **Favorites (saved listings)** and **Reports** (users can report a listing/user).

### Next
8. Ratings & reviews (one per user per listing, aggregated server-side).
9. Push notifications (new message, listing approved/rejected).
10. Payments (see §8).
11. Phone-number OTP login, map/location view, "verified landlord" badge, featured/boosted listings.

---

## 5. Architecture

Use a **feature-first** structure with a simple layered split (UI → controller/provider → repository → Firebase). Screens must **not** call Firestore directly.

```text
lib/
 ├── main.dart                     # Firebase init, App Check, ProviderScope
 ├── app.dart                      # MaterialApp.router, theme
 ├── firebase_options.dart         # generated, do not edit
 ├── core/
 │    ├── constants/               # categories, Arua areas, collection names, UGX formatter
 │    ├── theme/                   # AppTheme (primary #FF5722), text styles
 │    ├── router/                  # go_router config + role guards
 │    ├── utils/                   # validators, phone normalizer, debouncer
 │    ├── widgets/                 # shared: AppButton, LoadingView, ErrorView, EmptyView, AppNetworkImage
 │    └── errors/                  # AppException, error mapping from FirebaseException
 ├── features/
 │    ├── auth/        (data/ domain/ presentation/)
 │    ├── listings/    (browse, detail, search, filters)
 │    ├── provider/    (dashboard, upload/edit listing)
 │    ├── admin/       (moderation, role requests, stats)
 │    ├── chat/
 │    ├── ratings/
 │    ├── favorites/
 │    ├── payments/
 │    └── profile/
 └── l10n/                         # English first; keep strings out of widgets
functions/                         # Cloud Functions (TypeScript)
firestore.rules
storage.rules
firestore.indexes.json
```

Each feature: `data/` (models, repository implementation), `domain/` (repository interface, optional), `presentation/` (screens, widgets, Riverpod providers/controllers).

> **Change from the original brief:** the old layout (`screens/` + `services/` flat folders) works for a prototype but becomes unmanageable. If migrating, move one feature at a time and keep the app compiling after each step.

**Routing:** use `go_router` with a redirect guard based on auth state and role. Web needs real URLs (`/listing/:id`) so links are shareable.

---

## 6. Firestore Data Model

Use `snake_case`-free, camelCase field names. All documents have `createdAt` and `updatedAt` (server timestamps).

**`users/{uid}`**
`name, email, phone, photoUrl, role ('tenant'|'landlord'|'provider'|'admin'), roleRequest?, isVerified, fcmTokens[], createdAt`

**`listings/{listingId}`**
`ownerId, ownerName, ownerPhone, type ('property'|'service'), category, title, titleLower, description, priceUgx (int), priceUnit ('month'|'job'|'hour'|'fixed'), area, address?, geo? (GeoPoint), bedrooms?, bathrooms?, amenities[], imageUrls[], thumbnailUrl, videoUrl?, status ('pending'|'approved'|'rejected'), rejectionReason?, ratingAvg (number), ratingCount (int), searchKeywords[], isFeatured, createdAt, updatedAt`

**`chat_rooms/{roomId}`** — `roomId` is **deterministic**: sorted `uidA_uidB_listingId` (prevents duplicate rooms).
`participants[2], listingId, lastMessage, lastMessageAt, unreadCount{uid: n}`
→ subcollection **`messages/{messageId}`**: `senderId, text, type ('text'|'image'), createdAt, readBy[]`

**`reviews/{listingId_userId}`** — deterministic ID enforces **one review per user per listing**.
`listingId, listingOwnerId, userId, userName, rating (1–5), comment, createdAt`
(The listing's `ratingAvg/ratingCount` are updated by a Cloud Function trigger, **never** by the client.)

**`favorites/{userId}/items/{listingId}`** (owner-managed), **`reports/{reportId}`** (user-submitted), **`role_requests/{uid}`** (owner-created, admin-reviewed), **`payments/{txRef}`** (written only by Cloud Functions).

`role_requests/{uid}` is created by the owner with `uid, requestedRole, status: 'pending', name, email, phone, createdAt, updatedAt`. Admin review adds `reviewedBy` and `reviewedAt`; rejection also records `rejectionReason`. The user's `role` remains `tenant` until approval updates both the request and `users/{uid}` in one batch. Payments are the collection written only by Cloud Functions.

**Query & index rules**
- Public browse query: `where('status', isEqualTo: 'approved')` + optional `category`/`area` filters + `orderBy('createdAt', descending: true)` + `limit(20)` + `startAfterDocument`. Commit composite indexes to `firestore.indexes.json`.
- Firestore has **no full-text search**. For MVP, use `searchKeywords` (lowercased tokens/prefixes) with `array-contains`. If search quality becomes important, move to Algolia or Typesense.
- Never stream the whole `listings` collection. Always paginate. Use `.get()` for lists that don't need live updates; use streams only for chat and the provider's own dashboard.
- Denormalize small fields (owner name, thumbnail) onto listings to avoid N+1 reads.

---

## 7. Security Rules (must be written & tested)

Copilot: generate `firestore.rules` and `storage.rules` that enforce at least:

- Public/tenants can read `listings` **only where `status == 'approved'`**; owners can read their own; admins read all.
- A listing **create** must set `ownerId == request.auth.uid`, `status == 'pending'`, and the user's role must be `landlord`/`provider`. **Update by owner must reset `status` to `'pending'`** and cannot change `ownerId`, `ratingAvg`, `ratingCount`, `isFeatured`.
- Only admin can set `status` to `approved`/`rejected`.
- `users/{uid}`: owner may update only whitelisted fields (not `role`, `isVerified`).
- `chat_rooms`/`messages`: only `participants` can read/write; message `senderId == auth.uid`.
- `reviews`: create only if signed in, doc ID matches `listingId_uid`, rating 1–5, can't review own listing.
- `payments`: **read-only for the owner; no client writes**.
- Storage: only the owner can write to `listings/{uid}/...`; enforce `request.resource.size` limits and `contentType` (images/video only); public read of approved media only if feasible, otherwise authenticated read.
- Enable **App Check** enforcement for Firestore, Storage, and Functions.
- Add **emulator-based rules tests** (`@firebase/rules-unit-testing`).

---

## 8. Payments (Flutterwave) — Design Constraints

- **Never put the Flutterwave secret key in the Flutter app.** Only the public key may be in the client. Treat the app binary as public.
- Flow: client asks a **Cloud Function** to create a payment (`txRef`, amount, currency `UGX`, payer) → client opens Flutterwave checkout with that `txRef` → Flutterwave calls our **webhook** (verify the signature header/secret hash) → Function **verifies the transaction via Flutterwave's verify API** (status, amount, currency, txRef) → Function writes the `payments/{txRef}` result and updates the related record. **The app only displays what Firestore says; it never marks anything as paid itself.**
- Make webhook handling **idempotent** (same event twice must not double-apply).
- Support MTN Mobile Money and Airtel Money (Uganda) plus cards. Handle pending/failed/timeout states and show clear retry UI.
- **Scope decision needed before building:** paying *rent directly landlord-to-tenant* involves money movement between third parties (split payments / subaccounts, payouts, KYC, possible regulatory requirements). Recommended MVP: use payments for **platform revenue** (listing fees, featured/boosted listings, or a viewing/booking deposit). Treat landlord payouts as a later phase after checking Flutterwave's requirements and Ugandan regulations.
- Never log card or phone-payment details.

---

## 9. UI/UX Guidelines

- Jumia-inspired: clean white surfaces, **primary `#FF5722`**, 2-column grid on phones, 3–4 columns on tablet/desktop web (use `SliverGridDelegateWithMaxCrossAxisExtent`, not a fixed count).
- Use **Material 3**, `ColorScheme.fromSeed`, a central `AppTheme`. No hard-coded colors/sizes inside widgets.
- Every list/detail screen needs: **loading skeleton/shimmer, empty state, error state with retry**.
- Use `CachedNetworkImage` everywhere with placeholder + error widget, requesting thumbnail-size images in grids.
- Large tap targets (≥48dp), readable text, support dark mode later but light mode first.
- Accessibility: semantic labels on icons/images, sufficient contrast (white text on `#FF5722` is borderline — use dark text or a darker shade for small text).
- Forms: validate on client (UX) **and** in rules/functions (security). Disable submit while uploading; show upload progress.
- Web/PWA: responsive max-content-width, keyboard & mouse support, proper page titles, deep links.

---

## 10. Build & Release Checklist

**Android**
- `minSdkVersion 23`, set `applicationId`, app label, adaptive launcher icon, splash screen.
- Create a release **keystore**, configure `key.properties` (git-ignored), enable R8/minify and shrink resources.
- Ship **AAB** for Play Store, and a split-per-ABI **APK** for direct sharing (`flutter build apk --split-per-abi`).
- Add Firebase **SHA-1/SHA-256** fingerprints for debug and release.

**Web / PWA**
- Update `web/manifest.json` (name, short_name, `theme_color #FF5722`, icons incl. maskable 192/512), `index.html` meta tags, and a proper favicon.
- Prefer the default Flutter web build; test with `--web-renderer` options only if performance requires.
- Host on Firebase Hosting with SPA rewrites to `index.html`.

**Environments:** `dev` and `prod` Firebase projects (use FlutterFire flavors). Never test against production data.

---

## 11. Rules for Copilot (How to Work on This Repo)

**General**
1. Follow the structure in §5. Put new code in the correct feature folder; don't create files at random locations.
2. **Do not change architecture, packages, or data model without asking.** If something here seems wrong, say so and propose an alternative rather than silently deviating.
3. Make **small, reviewable changes**: one feature/fix per change, app must compile after each. When a task is large, outline a plan first, then implement step by step.
4. Don't invent APIs. If unsure about a package's API or version, say so and check the docs/`pubspec.lock`.

**Code quality**
5. Dart 3, sound null safety, `final`/`const` wherever possible, enable and obey `flutter_lints`. Keep widgets small; extract subwidgets rather than 300-line `build` methods.
6. Use **models with `fromFirestore`/`toFirestore`** (or `json_serializable`/`freezed`), not raw `Map<String, dynamic>` in UI code.
7. Repositories return typed models and throw/return an `AppException`; **wrap Firebase calls in try/catch**, map `FirebaseException` codes to friendly messages, never show raw errors to users.
8. Always handle `mounted` checks after `await` before using `BuildContext`. Dispose controllers/subscriptions.
9. Use Riverpod providers (`AsyncNotifier`/`StreamProvider`) for state; no business logic inside widgets.
10. Money is `int` UGX. Dates stored as `Timestamp`/server timestamps, displayed in `Africa/Kampala` locale.

**Firestore / performance**
11. Paginate every list; avoid unbounded reads; avoid reading inside loops. Add the needed index to `firestore.indexes.json` whenever a new compound query is written.
12. Use server timestamps (`FieldValue.serverTimestamp()`), transactions/batched writes for multi-document updates.
13. Compress images before upload; generate thumbnails; cap file sizes; show progress and allow cancel.

**Security (non-negotiable)**
14. No secrets, API keys (other than public client keys), or service-account files in the repo. Use `.env`/Functions config/Secret Manager; keep them in `.gitignore`.
15. Anything involving money, roles, ratings aggregates, or approval status is **decided on the server** (Rules / Cloud Functions), never trusted from the client.
16. Whenever you add a collection or field, also update `firestore.rules` and add/adjust a rules test.
17. Validate and sanitize all user input (length limits, phone format, price > 0, allowed categories/areas).

**Testing & docs**
18. Add unit tests for models/validators/repositories (with `fake_cloud_firestore` or the emulator) and widget tests for key screens. Run `flutter analyze` and `flutter test` before suggesting a change is done.
19. Keep this file accurate: if a change alters architecture or data model, propose an update to this document.

**When I paste an error:** identify the root cause in this project's context, explain it in 1–2 sentences, then give the exact, copy-pasteable fix (file path + code). If more info is needed (e.g. package versions, full stack trace), ask for it.

**When I ask for UI work:** produce responsive, themed widgets using the shared components, include loading/empty/error states, and don't hard-code colors or strings.

---

## 12. Suggested Build Order (for Copilot Chat prompts)

1. Project setup: packages, theme, lints, folder skeleton, `go_router`, Riverpod, Firebase init + App Check.
2. Auth feature + `users` model + role-request flow + route guards.
3. `firestore.rules` / `storage.rules` + emulator tests for users/listings.
4. Listings model + repository + paginated home grid + search/filter + detail page.
5. Provider dashboard + upload/edit listing (image compress, video limit, progress).
6. Admin moderation (approve/reject with reason, role requests) + admin custom-claim script.
7. Contact buttons (call/WhatsApp) + chat (deterministic rooms, unread counts) + FCM.
8. Favorites, reports, ratings (with Cloud Function aggregation).
9. Payments (Cloud Functions + webhook + verification) after scope decision in §8.
10. PWA polish, Android release config, Firebase Hosting, Play Store prep.

---

## 13. Open Decisions (resolve before the related step)

- [ ] Payments scope: platform fees only, or full rent payments with payouts? (§8)
- [ ] Search approach: `searchKeywords` MVP vs. Algolia/Typesense.
- [ ] Add phone-OTP login in MVP or later?
- [ ] Do landlords need identity verification (ID/NIN, proof of ownership) before the "Verified" badge?
- [ ] Languages: English only, or also Lugbara/Swahili strings?
- [ ] Moderation policy: required listing fields, prohibited content, how rejection reasons are worded.
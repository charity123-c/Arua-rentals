# Arua City Finder (Arua Rentals)

A Flutter marketplace for finding rental properties and local housing services in
**Arua City, Uganda**. Tenants can browse and save listings, landlords and service
providers can publish listings, and administrators moderate the marketplace from a
dedicated dashboard.

The application targets **Android** and **web (PWA)**, with the same codebase also
building for iOS, macOS, and Windows. It is designed for mid-range Android devices
and expensive mobile data, so lists are paginated, images are loaded through
`cached_network_image`, and browsing works without signing in.

---

## Table of contents

- [Features](#features)
- [Roles and permissions](#roles-and-permissions)
- [Tech stack](#tech-stack)
- [Architecture](#architecture)
- [Routes](#routes)
- [Firestore data model](#firestore-data-model)
- [Getting started](#getting-started)
- [Firebase setup](#firebase-setup)
- [Admin bootstrap and sample data](#admin-bootstrap-and-sample-data)
- [Testing](#testing)
- [Building for release](#building-for-release)
- [Security notes](#security-notes)
- [Current limitations and roadmap](#current-limitations-and-roadmap)
- [Contributing](#contributing)

---

## Features

### Public browsing

- Public, shareable home page at `/` with approved listings only.
- Search with debounced keyword filtering backed by denormalized
  `searchKeywords` and `array-contains`.
- Category and area filters, plus sorting by newest, lowest price, or highest
  price.
- Infinite scroll with 20-item pages and cursor-based pagination.
- Featured listings section and responsive 2-column grid on phones, wider grids
  on tablets and desktop.
- Loading skeletons, empty states, error states with retry, and pull-to-refresh.
- Responsive detail page at `/listing/:id` with image gallery, amenities,
  bedrooms/bathrooms, price, area, and owner information.
- Contact actions: Call, WhatsApp, and in-app chat. Unapproved listings are
  visible only to their owner or an administrator.

### Accounts and roles

- Firebase Authentication email/password registration and login.
- Password reset flow.
- Automatic `users/{uid}` profile creation on first sign-in.
- Role requests: a new user starts as `tenant` and can request `landlord` or
  `provider`. An administrator approves or rejects the request.
- Admin access requires **both** a `users/{uid}` profile with `role: admin` and
  the Firebase Auth custom claim `admin: true`. The UI downgrades a profile-only
  admin to tenant, and Firestore Rules enforce the claim server-side.
- Redirect-aware authentication: protected routes send visitors to
  `/login?redirect=...` and return them safely after sign-in.

### Provider workspace

- Landlords and providers see their own listings with `Live`, `Pending`, and
  `Rejected` status badges.
- Create and edit listings with validation for Ugandan phone numbers, positive
  integer UGX prices, controlled categories and areas, amenities, image URLs,
  and property details.
- New and edited listings are always submitted as `pending`. Only administrators
  can approve, reject, feature, or verify listings.
- Delete owned listings.
- Rejected listings display the administrator's rejection reason.

### Favorites and chat

- Save or unsave approved listings. Favorites are stored privately under
  `favorites/{uid}/items/{listingId}` as typed listing snapshots.
- Paginated favorites screen with availability checks so deleted or unapproved
  listings are no longer actionable.
- In-app chat with deterministic room IDs
  (`sortedUidA_sortedUidB_listingId`) that prevent duplicate conversations.
- Inbox ordered by latest message, unread counters per participant, paginated
  message history, and transactional sends that update the room metadata and
  insert the message atomically.

### Admin dashboard

- Overview statistics for total users and listing/role-request queues.
- Pending role-request queue with approve and reject-with-reason actions.
- Pending listing moderation with approve and reject-with-reason actions.
- Full listing management, including creating and editing listings on behalf of
  an owner.
- User management: search by name or email, change role between tenant,
  landlord, and provider, edit profile details, verify users, and delete
  profiles. Admin cannot be granted from the client.
- Verification is propagated to all listings owned by the user in chunked
  batches of up to 400 writes.
- Marketplace configuration: manage active categories and areas, or seed the
  defaults. Configuration is public-read and admin-write only.

### Design and UX

- Material 3 theme seeded from `#FF5722`.
- Central design tokens for spacing, radius, elevation, layout widths, and
  animation durations.
- Responsive layouts: bottom navigation on phones, navigation rail on wide
  screens.
- Consistent loading, empty, and error components across features.
- Currency is always an integer amount in UGX, formatted like `UGX 350,000`.

---

## Roles and permissions

| Capability | Tenant | Landlord / Provider | Admin |
| --- | :---: | :---: | :---: |
| Browse approved listings | Yes | Yes | Yes |
| Save favorites and chat | Yes | Yes | Yes |
| Request landlord/provider role | Yes | — | — |
| Create, edit, delete own listings | No | Yes (submitted `pending`) | Yes |
| View own pending/rejected listings | No | Yes | Yes |
| Approve or reject listings | No | No | Yes |
| Feature or verify listings | No | No | Yes |
| Review role requests | No | No | Yes |
| Manage users and marketplace config | No | No | Yes |

Enforcement lives in `firestore.rules`; UI guards are for user experience only.
The `admin` custom claim can only be assigned with the Firebase Admin SDK script
in `tools/`.

---

## Tech stack

| Layer | Technology |
| --- | --- |
| Framework | Flutter / Dart 3 (null safety) |
| State management | Riverpod (`flutter_riverpod`) |
| Navigation | `go_router` with auth and role redirects |
| Authentication | Firebase Authentication (email/password) |
| Database | Cloud Firestore (paginated queries, transactions, batched writes) |
| Media | Image URLs today; Firebase Storage integration planned |
| Notifications | `firebase_messaging` dependency present; not wired into the UI yet |
| Security | Firestore Security Rules with emulator-based tests |
| Images | `cached_network_image`, `flutter_image_compress`, `image_picker` |
| Utilities | `intl`, `url_launcher`, `shared_preferences` |
| Linting | `flutter_lints` |
| Test tools | `flutter_test`, `fake_cloud_firestore`, `@firebase/rules-unit-testing` |

---

## Architecture

The app follows a feature-first layered structure:

```text
lib/
├── main.dart                    # Firebase init and ProviderScope
├── app.dart                     # MaterialApp.router and theme
├── firebase_options.dart        # Generated FlutterFire configuration
├── core/
│   ├── constants/               # Collections, Arua areas, categories, UGX formatter
│   ├── errors/                  # AppException and Firebase error mapping
│   ├── router/                  # go_router config and role access helpers
│   ├── theme/                   # AppTheme and design tokens
│   ├── utils/                   # Validators and Ugandan phone normalizer
│   └── widgets/                 # Shared loading, error, empty, shimmer, image widgets
├── features/
│   ├── admin/                   # Dashboard, queues, users, settings, repository
│   ├── auth/                    # Login, register, reset, user model, repository
│   ├── chat/                    # Inbox, chat room, chat repository
│   ├── favorites/               # Saved listings, favorite button, repository
│   └── listings/                # Browse, detail, forms, provider/admin listings
├── models/                      # Legacy prototype models
├── screens/                     # Legacy prototype screens
├── services/                    # Legacy prototype services
└── data/                        # Legacy mock data
```

Each feature contains `data/` (models and repositories) and `presentation/`
(screens, widgets, and Riverpod providers). Screens do not call Firestore
directly; they use typed repositories that throw `AppException` with friendly
messages.

The `models/`, `screens/`, `services/`, and `data/` folders are retained from the
original prototype and are not part of the active routed application. New work
belongs in `lib/features/` and `lib/core/`.

---

## Routes

| Route | Screen | Access |
| --- | --- | --- |
| `/` | Public listings browser | Public |
| `/listing/:id` | Listing detail | Public for approved listings |
| `/login` | Email/password login | Public |
| `/register` | Account registration and role request | Public |
| `/forgot-password` | Password reset | Public |
| `/provider` | Provider/landlord listing workspace | Landlord, provider, admin |
| `/favorites` | Saved listings | Signed-in users |
| `/chat` | Chat inbox | Signed-in users |
| `/chat/:roomId` | Chat conversation | Chat participants |
| `/admin` | Admin dashboard | Admin profile plus `admin` claim |
| `/access-denied` | Access denied message | Signed-in users |

Authorization redirects are centralized in `lib/core/router/app_router.dart`.
`lib/core/router/role_access.dart` resolves the effective role and admin access.

---

## Firestore data model

| Path | Purpose |
| --- | --- |
| `users/{uid}` | Profile, role, verification badge, FCM tokens |
| `role_requests/{uid}` | Pending landlord/provider request and review result |
| `listings/{listingId}` | Public marketplace listing |
| `favorites/{uid}/items/{listingId}` | Private saved-listing snapshot |
| `chat_rooms/{roomId}` | Deterministic two-participant conversation |
| `chat_rooms/{roomId}/messages/{messageId}` | Immutable chat messages |
| `config/categories` | Admin-managed listing categories |
| `config/areas` | Admin-managed Arua areas |

Important conventions:

- All money is stored as an integer `priceUgx`; never use floating point for
  currency.
- Dates use Firestore `Timestamp` values and server timestamps.
- Listing IDs are generated client-side with random document IDs.
- Chat room IDs are deterministic:
  `${firstUid}_${secondUid}_${listingId}` with UIDs sorted.
- Listing search uses lowercased prefix tokens in `searchKeywords` with
  `array-contains`; this is the MVP replacement for full-text search.
- Composite indexes for every browse, sort, filter, owner, chat, and moderation
  query are committed in `firestore.indexes.json`.

### Listing document

```text
ownerId, ownerName, ownerPhone, type ('property' | 'service'),
category, title, titleLower, description, priceUgx (int),
priceUnit ('month' | 'job' | 'hour' | 'fixed'), area, address?,
geo? (GeoPoint), bedrooms?, bathrooms?, amenities[], imageUrls[],
thumbnailUrl, videoUrl?, status ('pending' | 'approved' | 'rejected'),
rejectionReason?, ratingAvg (number), ratingCount (int),
searchKeywords[], isFeatured, ownerVerified, createdAt, updatedAt
```

### User document

```text
name, email, phone, role ('tenant' | 'landlord' | 'provider' | 'admin'),
roleRequest?, photoUrl?, fcmTokens[], isVerified, createdAt, updatedAt
```

### Chat room document

```text
participants[2], listingId, listingTitle, listingThumb,
lastMessage, lastMessageId, lastMessageAt,
unreadCount{uid: int}, createdAt
```

Messages contain only `senderId`, `text`, and `createdAt`. Messages are immutable
after creation.

---

## Getting started

### Prerequisites

- Flutter stable with Dart `>= 3.13.1`
- Android Studio / Android SDK for Android builds, or a modern browser for web
- Firebase CLI (`npm install -g firebase-tools`)
- FlutterFire CLI (`dart pub global activate flutterfire_cli`) if you need to
  regenerate Firebase configuration for another project
- Node.js 20+ for the Firestore Rules tests and admin tools
- Java 17+ for the Firestore emulator

### Install dependencies

```powershell
git clone https://github.com/charity123-c/Arua-rentals.git
cd Arua-rentals
flutter pub get
```

The repository already contains generated Firebase client configuration for the
`arua-city-finder` project in `lib/firebase_options.dart` and `firebase.json`.
To use your own Firebase project, regenerate that file:

```powershell
firebase login
flutterfire configure --project=<your-firebase-project-id>
```

> Never commit service-account JSON files. `.gitignore` already excludes
> `service-account*.json`, `.env`, keystores, and other local secrets.

### Run the app

```powershell
flutter run -d chrome
flutter run -d <android-device-id>
```

Other desktop targets:

```powershell
flutter run -d windows
flutter run -d macos
```

Linux is not configured in `firebase_options.dart`.

---

## Firebase setup

1. Create or select a Firebase project.
2. Enable **Authentication > Sign-in method > Email/Password**.
3. Create a **Cloud Firestore** database.
4. Configure your app with `flutterfire configure` if you are not using the
   committed project configuration.
5. Deploy rules and indexes:

   ```powershell
   firebase deploy --only firestore:rules,firestore:indexes
   ```

6. Seed marketplace configuration. Sign in as an admin, open
   **Admin > Settings**, and choose **Seed defaults**, or create
   `config/categories` and `config/areas` manually. The app falls back to the
   defaults in `lib/core/constants/listing_categories.dart` and
   `lib/core/constants/arua_areas.dart` when those documents are missing.
7. Optional: start the Firestore emulator for local development:

   ```powershell
   firebase emulators:start --only firestore
   ```

Firebase Storage, App Check, and FCM are dependencies of the project but are not
enabled in the current client flow. See [Current limitations](#current-limitations-and-roadmap).

---

## Admin bootstrap and sample data

Administrator access is intentionally impossible to grant from the client. Use
the trusted scripts in `tools/` with a service account:

```powershell
npm --prefix .\tools install
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\secure\service-account.json'
node .\tools\set_admin.js 'admin@example.com'
Remove-Item Env:GOOGLE_APPLICATION_CREDENTIALS
```

After the script runs, sign out and sign in again so Firebase Auth refreshes the
ID token and includes the `admin` claim.

Seed 15 sample approved listings owned by an admin:

```powershell
node .\tools\seed_listings.js 'admin@example.com' --clear
```

Backfill `ownerVerified` on existing listings from each owner's profile:

```powershell
node .\tools\backfill_owner_verified.js --dry-run
node .\tools\backfill_owner_verified.js
```

See [`tools/README.md`](tools/README.md) for full details, safety notes, and
credential handling.

---

## Testing

### Flutter tests

Repository and widget tests use `fake_cloud_firestore`; they do not require the
Firestore emulator or network access.

```powershell
flutter analyze
flutter test
```

Coverage includes authentication validation, Firebase error mapping, role access
rules, listing pagination/filtering, featured listings, admin repository
transactions, favorites, chat rooms/messages, and public widget behavior.

### Firestore Rules tests

Security Rules are evaluated by the Firestore emulator, not by `flutter test`.

```powershell
npm install
npm run test:rules
```

The command starts the emulator against the `demo-arua-city-finder-rules`
project and runs `tests/firestore.rules.test.cjs`. It verifies:

- Owner-only profile access and blocked role escalation.
- Role-request creation and admin-only review.
- Public read access limited to approved listings and config.
- Owner/admin listing creation, update, rejection, and deletion rules.
- Private favorites with a fixed schema.
- Participant-only chat rooms and messages.
- Default-deny behavior for unlisted collections.

Run the rules tests before deploying `firestore.rules`.

---

## Building for release

### Web / PWA

```powershell
flutter build web --release
```

Deploy the generated `build/web` directory to Firebase Hosting or any static
host. The PWA manifest and icons live in `web/`.

### Android APK

```powershell
flutter build apk --release --split-per-abi
```

### Android App Bundle (Play Store)

```powershell
flutter build appbundle --release
```

Before publishing:

- Add release SHA-1/SHA-256 fingerprints to Firebase.
- Configure `android/key.properties` and a release keystore locally; both are
  git-ignored.
- Set the final application ID, app label, launcher icons, and splash screen.
- Test against a non-production Firebase project.

---

## Security notes

- Clients never choose their own privileged role. Registration always creates
  `tenant`; role changes require an approved role request.
- Admin requires a custom claim that only the Admin SDK script can set.
- Listing owners cannot set `ownerVerified`, `isFeatured`, `ratingAvg`, or
  `ratingCount`; Firestore Rules reject those writes.
- New and edited provider listings are forced to `pending`.
- Favorites and chat rooms are readable only by their owners/participants.
- All unlisted collections are denied by default.
- The Firebase client API keys in `lib/firebase_options.dart` are public client
  identifiers, not server secrets. Protect the project with Firebase Security
  Rules and App Check.
- Never commit a service account, admin credentials, `.env` file, or signing
  keystore.

---

## Current limitations and roadmap

Implemented today:

- Public browse, search, filters, sorting, pagination, detail pages, and contact
  links.
- Authentication, role requests, provider listing CRUD, favorites, chat, and the
  admin dashboard.
- Firestore Rules plus emulator-based rules tests.

Not yet wired into the client:

- Firebase Storage uploads. Listing images currently accept validated public
  URLs through `UrlMediaUploader`; replace it with a Storage-backed uploader when
  the Blaze plan is available.
- App Check enforcement. `main.dart` has a TODO because console providers and
  debug tokens are not configured yet.
- Push notifications. `firebase_messaging` is present but no FCM token
  registration or notification handling is active.
- Ratings and reviews. `RatingService` exists as a prototype, but no routed UI or
  Cloud Function aggregation is connected.
- Reports, payments, phone OTP login, maps, and boosted listings. These are
  planned but not part of the current app.
- Chat message pagination UI and per-message read receipts.

Recommended next steps:

1. Enable Firebase Storage and implement compressed image uploads with progress.
2. Add Cloud Functions for rating aggregation, role claims, and notification
   delivery.
3. Wire App Check for Firestore, Storage, and Functions.
4. Add integration tests against the emulator suite.
5. Add CI for `flutter analyze`, `flutter test`, and `npm run test:rules`.

---

## Contributing

1. Create a branch from `main`.
2. Keep changes feature-scoped and follow the existing feature-first layout.
3. Put business logic in repositories/providers, not widgets.
4. Update `firestore.rules`, `firestore.indexes.json`, and the corresponding
   tests whenever you add a collection, field, or compound query.
5. Run `flutter analyze`, `flutter test`, and `npm run test:rules` before
   opening a pull request.
6. Do not commit secrets or local configuration.

No license file is included in this repository. Add one before redistributing
the project.

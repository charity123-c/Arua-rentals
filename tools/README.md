# Admin bootstrap tool

This local tool assigns the existing Firebase Auth user the `admin: true`
custom claim and creates or merges the matching `users/{uid}` profile with
`role: 'admin'`. Run it only from a trusted administrator's machine. Never
commit the service-account JSON file.

## Windows PowerShell

From the repository root, install the tool dependency once:

```powershell
npm --prefix .\tools install
```

Set the environment variable to the service-account JSON downloaded from the
Firebase project settings (use the actual path on your computer):

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\secure\path\service-account-arua-city-finder.json'
```

Run the script with the email of the existing Firebase Authentication user:

```powershell
node .\tools\set_admin.js 'admin@example.com'
```

After a successful run, sign out and sign in again so Firebase Auth refreshes
the user's ID token and the `admin` claim is available to the app. Clear the
environment variable when finished:

```powershell
Remove-Item Env:GOOGLE_APPLICATION_CREDENTIALS
```

The script preserves other custom claims and merges the profile fields without
overwriting an existing `createdAt`. It writes the profile before granting the
claim, so a failure between those operations leaves the account without admin
access. Inspect both the user's custom claims and `users/{uid}` before retrying.

## Seed sample listings

The seed utility creates 15 approved listings owned by the supplied Firebase
Auth admin account. It reads the active categories and areas from Firestore
`config/categories` and `config/areas`, falling back to the app defaults when
configuration is unavailable or has no active options. Each record is marked
`seeded: true`; the sample images are public Unsplash URLs.

From the repository root, install the Admin SDK dependency if you have not
already done so:

```powershell
npm --prefix .\tools install
```

Set the service-account path for the Firebase project:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\secure\path\service-account-arua-city-finder.json'
```

Create the sample listings for an existing admin account:

```powershell
node .\tools\seed_listings.js 'admin@example.com'
```

To delete existing seeded listings and create a fresh sample set in one run:

```powershell
node .\tools\seed_listings.js 'admin@example.com' --clear
```

`--clear` only deletes documents whose `seeded` field is exactly `true`.
Remove the credential path when finished:

```powershell
Remove-Item Env:GOOGLE_APPLICATION_CREDENTIALS
```

## Backfill listing verification badges

The backfill copies each listing owner's `users/{uid}.isVerified` value to
`listings/{listingId}.ownerVerified`. It reads credentials from
`GOOGLE_APPLICATION_CREDENTIALS` and processes at most 400 listing writes per
batch. A missing owner profile or invalid owner ID stops the migration with an
error rather than guessing the verification value.

Set the service-account path from the repository root:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\secure\path\service-account-arua-city-finder.json'
```

Preview the number of listings that would change without writing any data:

```powershell
node .\tools\backfill_owner_verified.js --dry-run
```

Apply the backfill:

```powershell
node .\tools\backfill_owner_verified.js
```

Clear the credential path when finished:

```powershell
Remove-Item Env:GOOGLE_APPLICATION_CREDENTIALS
```

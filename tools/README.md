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

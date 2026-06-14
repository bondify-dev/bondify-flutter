# Publishing the Bondify Flutter SDK — full setup guide

This walks you through everything from zero: creating the GitHub org/repo,
pushing the package, letting people install it from Git, and (optionally)
publishing to **pub.dev** so users can just write `bondify_flutter: ^1.0.0`.

You can stop after **Part A** (Git install works immediately) and do **Part B**
(pub.dev) later.

---

## Part A — GitHub repository (install via Git)

### A1. Create a GitHub account / organization
1. Sign up at https://github.com (skip if you have an account).
2. (Recommended) Create an **organization** named `bondify` so the URL matches
   the docs: GitHub → top-right **+** → **New organization** → Free plan →
   name it `bondify`.
   - If you can't get the name `bondify`, pick another (e.g. `bondify-dev`) and
     change the `url:`/`repository:` fields accordingly everywhere
     (`pubspec.yaml`, README, and the docs install snippet).

### A2. Create the repository
1. On the `bondify` org page → **Repositories** → **New**.
2. Repository name: **`bondify-flutter`** (this makes the final URL
   `https://github.com/bondify/bondify-flutter`, which is what the docs use).
3. Visibility: **Public** (required so `flutter pub get` can fetch it).
4. Do **not** add a README/license/gitignore (the package already has them).
5. Click **Create repository**.

### A3. Push the package
From the folder that contains this SDK (the one with `pubspec.yaml`):

```bash
# one-time identity setup (skip if already done)
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"

git init
git add .
git commit -m "Bondify Flutter SDK v1.0.0"
git branch -M main
git remote add origin https://github.com/bondify/bondify-flutter.git
git push -u origin main
```

> If GitHub asks for a password on push, it actually wants a **Personal Access
> Token**, not your account password:
> GitHub → **Settings** → **Developer settings** → **Personal access tokens** →
> **Tokens (classic)** → **Generate new token** → tick **repo** → copy it and
> use it as the password. (Or install the **GitHub CLI** `gh` and run
> `gh auth login`.)

### A4. Tag the release
The docs pin a version with `ref: v1.0.0`, so create that tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

✅ **Done.** Anyone can now install it:

```yaml
dependencies:
  bondify_flutter:
    git:
      url: https://github.com/bondify/bondify-flutter
      ref: v1.0.0
```

For future releases: bump `version:` in `pubspec.yaml`, update `CHANGELOG.md`,
commit, then `git tag v1.0.1 && git push origin v1.0.1`.

---

## Part B — Publish to pub.dev (so users write `bondify_flutter: ^1.0.0`)

This is optional but makes installation cleaner and gives you a pub.dev page.

### B1. Pre-flight checks
From the package folder:

```bash
flutter pub get
dart format .
flutter analyze          # fix any issues it reports
flutter test             # the included tests should pass
dart pub publish --dry-run
```

`--dry-run` validates everything pub.dev requires (valid `pubspec.yaml`,
`LICENSE`, `CHANGELOG.md`, a description of the right length, an example, etc.).
Fix anything it flags. This package is already structured to pass.

### B2. Make sure these are correct in `pubspec.yaml`
- `name: bondify_flutter` — must be globally unique on pub.dev. If it's taken,
  rename (e.g. `bondify` or `bondify_auth`) and update imports.
- `description:` — 60–180 characters (already set).
- `homepage:` / `repository:` — real URLs (point `repository` at the GitHub repo
  from Part A).
- `version: 1.0.0`.

### B3. Publish
```bash
dart pub publish
```

- The first time, it opens a browser to log in with your Google account and
  authorize the pub.dev CLI.
- After you confirm, the package is **live within a minute** at
  `https://pub.dev/packages/bondify_flutter`.

> ⚠️ Publishing is **permanent** — you can't delete a version, only publish a
> newer one or mark a version discontinued. Get the dry-run clean first.

### B4. (Recommended) Verified publisher
On pub.dev you can verify ownership of `bondify.dev` so your package shows a
verified-publisher badge:
pub.dev → your package → **Admin** → **Verified publisher** → add `bondify.dev`
and complete DNS verification.

### B5. Future releases
```bash
# bump version in pubspec.yaml + add a CHANGELOG.md entry, then:
dart pub publish
```

---

## After publishing — flip the docs to pub.dev

Once it's on pub.dev, change the Flutter install snippet in the docs from the
Git form to the simple form:

```yaml
dependencies:
  bondify_flutter: ^1.0.0
```

(That snippet lives in `docs/quickstart` / the Flutter guide and in the
dashboard Docs tab.)

---

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `flutter pub get` fails with "could not find repo" | Repo must be **public** and the `url:` exact. Check the tag exists: `git ls-remote --tags origin`. |
| `pub publish` rejects the name | The name is taken — rename the package and update imports. |
| Push asks for a password and rejects it | Use a Personal Access Token or `gh auth login` (see A3). |
| Telegram doesn't open on Android 11+ | Add the `<queries>` block from the README to `AndroidManifest.xml`. |
| Users get "Enable Mobile SDK" error | Turn on **Mobile SDK** in the project settings — the public mobile flow requires it. |

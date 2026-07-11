# Changelog

All notable changes to `bondify_flutter` will be documented in this file.

## 1.0.1 — Uncaught polling exceptions, singleton callback clobbering

**Fixed:**

- **`_checkOnce` (the polling loop) could leave an uncaught exception
  escape a `Timer.periodic` callback.** It only caught `on BondifyException`;
  anything else (e.g. `VerifyResponse.fromJson` throwing a raw `TypeError`
  on an unexpected response shape) was not caught at all, silently leaving
  polling stuck with no `onError` feedback — undermining the 1.0.0 fix that
  made polling correctly surface definitive errors. Added a generic
  `catch (e)` fallback mirroring the one `startAuth()` already had around
  `generateSession()`.
- **`BondifyButton` and `BondifyAuthSheet` could silently clobber each
  other's `onSuccess`/`onError` callbacks.** `BondifyClient` is a singleton
  with a single mutable `onSuccess`/`onError` field; both widgets
  unconditionally overwrote it in `initState()` without restoring the
  previous value in `dispose()`. In an app using both together (e.g. a
  `BondifyButton` that opens a `BondifyAuthSheet`), the sheet's callback
  would silently replace the button's, and unmounting the sheet left the
  button's callback permanently lost instead of restored. Both widgets now
  save the previous callback on mount and restore it on dispose (only if
  they're still the active one — a widget that mounted after them and took
  over isn't clobbered back).

## 1.0.0 — Correct error codes, polling no longer swallows real errors

**Fixed:**

- **`BondifyErrorCode` now includes `projectInactive`**, matching the REST
  API and the `@bondify/react` SDK. It was missing entirely before, so a
  `PROJECT_INACTIVE` response from the backend had no corresponding enum
  value to map to.
- **The API client now reads the backend's machine-readable `code` field**
  from error responses instead of guessing the error code purely from the
  HTTP status. Several distinct failures share the same HTTP status (e.g.
  403 covers both `PUBLIC_ACCESS_DISABLED` and `PROJECT_INACTIVE` — see the
  REST API reference's Errors section), so status-only mapping could report
  the wrong `BondifyErrorCode`. The status-based mapping is kept as a
  fallback for the rare response that omits `code`.
- **Polling no longer silently swallows definitive backend errors.**
  Previously, *any* exception during a polling tick (network failure,
  project not found, project inactive, public access disabled, rate
  limited, …) was caught, logged with `debugPrint`, and polling continued
  indefinitely — the app never found out anything was wrong. Now only
  actual `networkError`s are retried silently; any other error code stops
  polling and calls `onError`, so your app can react to it instead of the
  sign-in flow hanging forever with no feedback.
- **`BondifyAuthSheet`'s error view no longer mislabels every failure as
  "link expired."** `BondifyAuthStatus.error` (now reachable more often
  thanks to the polling fix above) previously rendered the same "⏰ Ссылка
  истекла" ("the link has expired") header as `BondifyAuthStatus.expired`.
  It now shows a distinct "⚠️ Не удалось войти" ("couldn't sign you in")
  header for genuine errors, "⏰ Ссылка истекла" only for actual expiry, and
  "🚫 Вход отменён" for cancellation, alongside the specific error message
  as before.

**Documentation:**

- Added an "Android/iOS platform setup" section to the README covering the
  Android 11+ `<queries>` manifest requirement for opening the Telegram
  deep link via `url_launcher`.

## 0.9.0 — Initial release

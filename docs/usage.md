# Usage

## Browse and open entries

- Sidebar folders mirror your store paths (including nested folders).
- Select an entry to decrypt and view details.
- Click a password or field to copy. Clipboard auto-clear is configurable in Settings.

![Nested folders](screenshots/4-nested-folders.png)

![Entry with TOTP](screenshots/5-record.png)

## Create and edit

- **⌘N** or **+** — new entry (location, password, custom fields, optional OTP).
- **Edit** — change location, password, fields, or delete the entry.
- **Generate Password…** — fills a new password.

![New entry](screenshots/3-new-entry.png)

![Edit entry](screenshots/6-edit.png)

## Verification codes (TOTP)

Requires [pass-otp](plugins.md).

- Codes appear under **Code** when the entry contains `otpauth://…`.
- **Verification Codes** lists OTP entries after you have opened them at least once in this session (metadata comes from decrypt).

## Git sync

If the store is a Git repository:

- Use **Sync** in the sidebar for **Pull**, **Push**, and **Refresh**.
- **Settings → Sync** shows branch / ahead / behind.

![Git sync](screenshots/2-push.png)

## App Lock

Enable under **Settings → Security**.

- Locks the UI after idle timeout or **Lock Now** (`⌃⌘L`).
- Hiding the app (**⌘H**) or switching away does **not** lock NativePass.
- Unlock with Touch ID or device password (main window or Quick Access).
- Unlocking restores your previous sidebar folder, selected entry, and search. Decrypted contents are cleared on lock and loaded again when you open an entry.
- **Lock Now** does not auto-prompt Touch ID until you press **Unlock** (or open Quick Access).

## Quick Access

Global hotkey (default **⌥⌘P**) opens a compact search window — useful for fast copy without the full UI.

If NativePass is locked, Quick Access shows an unlock prompt first; after success you can search and copy as usual (the whole app unlocks).

| Shortcut | Action |
|----------|--------|
| **esc** / **⌘W** / ✕ | Close without decrypting |
| **↵** | Decrypt and copy password (then closes) |
| **⌘O** | Open the entry in the main window |

Configure under **Settings → General → Quick Access**.

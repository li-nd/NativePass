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

## Quick Access

Global hotkey (default **⌥⌘P**) opens a compact search window — useful for fast copy without the full UI.

Configure under **Settings → General → Quick Access**.

## App Lock

Enable under **Settings → Security**.

- Locks the UI after idle timeout or when the app goes to background.
- Unlock with Touch ID or device password.
- Manual **Lock Now** (`⌃⌘L`) does not auto-prompt Touch ID until you press **Unlock**.

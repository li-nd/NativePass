# Usage

Everyday workflow in the main window. Related topics: [Search](search.md), [Quick Access](quick-access.md), [App Lock](app-lock.md).

For fast copy or Auto-Type without the main window, use **⌥⌘P** — see [Quick Access](quick-access.md).

## Browse and open entries

- Sidebar folders mirror your store paths (including nested folders).
- Select an entry to decrypt and view details.
- Click a password or field to copy. Clipboard auto-clear is configurable in Settings.
- Use **Raw** / **Form** (top-right of the detail pane) to switch between structured fields and the decrypted file as plain text. The same control works while editing. **Edit** / **Cancel** / **Save** keep the current Raw or Form mode. **⌘C** still copies only the password (first line); **⌘⇧C** copies the entire raw entry.
- Find entries with [Search](search.md) (fuzzy match on paths).

### Keyboard

Focus regions (⇥ cycles **sidebar → list → search**; ⇧⇥ reverses). While editing an entry, ⇥ moves between form fields instead.

| Shortcut | Action |
|----------|--------|
| **⇥** / **⇧⇥** | Cycle focus: sidebar ↔ list ↔ search |
| **⌘1** | Focus sidebar |
| **⌘2** | Focus entry list |
| **⌘F** | Focus search |
| **↑** / **↓** | Move selected entry (also while search is focused) |
| **Esc** | Clear search and focus list; or cancel editing |
| **⌘N** | New entry |
| **⌘E** | Edit selected entry |
| **⌘S** | Save while editing |
| **⌘C** | Copy password (first line) |
| **⌘⇧C** | Copy entire raw entry |
| **⌃⌘P** | Git Push |
| **⌃⌘⇧P** | Git Pull |
| **⌃⌘L** | Lock Now (when App Lock is enabled) |
| **⌘,** | Settings |
| **⌥⌘P** | [Quick Access](quick-access.md) (configurable) |

Quick Access has its own keys (**esc**, **↑↓**, **⇥**, **↵**, **⌘↵**, **⌥⌘↵**, **⌘O**) — see [Quick Access](quick-access.md).


![Nested folders](screenshots/4-nested-folders.png)

![Entry with TOTP](screenshots/5-record.png)

## Create and edit

- **⌘N** or **+** — new entry (location, password, custom fields, optional OTP).
- **⌘E** / **Edit** — change location, password, fields, or delete the entry. **⌘S** saves; **Esc** cancels.
- **Generate Password…** — fills a new password.

![New entry](screenshots/3-new-entry.png)

![Edit entry](screenshots/6-edit.png)

## Verification codes (TOTP)

Requires [pass-otp](plugins.md).

- Codes appear under **Code** when the entry contains `otpauth://…`.
- **Verification Codes** lists OTP entries after you have opened them at least once in this session (metadata comes from decrypt).

## Git sync

If the store is a Git repository:

- Use **Sync** in the sidebar for **Pull**, **Push**, and **Refresh** (or **⌃⌘⇧P** / **⌃⌘P**).
- **Settings → Sync** shows branch / ahead / behind.

![Git sync](screenshots/2-push.png)

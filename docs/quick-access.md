# Quick Access

A floating popup for finding an entry and copying its password without opening the full NativePass window.

## Open and close

| How | Result |
|-----|--------|
| **Global hotkey** (default **⌥⌘P**) | Toggle: open if hidden, close if already open |
| Menu bar extra → **Quick Access** | Same toggle |
| **esc** / **⌘W** / ✕ | Close without copying |
| Click another app | Panel hides (`hidesOnDeactivate`) |
| App Lock engages | Popup is dismissed |

The panel appears near the mouse pointer (clamped to the current screen). NativePass must be running (including from the menu bar); the hotkey does not launch a quit app.

Change the global hotkey in **Settings → Quick Access**. Click the shortcut button, press the new combination (at least one modifier), or **Reset** to restore ⌥⌘P. Esc cancels recording.

## Search and list

- Uses the same [fuzzy path search](search.md) as the main window (whole store, paths only).
- Empty query lists all entries (alphabetically by path).
- The list shows up to **50** matches; narrow the query if you need something further down.
- Arrow keys / click change the selection. The first result is selected automatically as you type.
- Rows show the entry name, optional username (only if that entry was decrypted earlier in this session), and icons for URL / OTP when metadata is known.
- Each row has a copy button; **↵** copies the **selected** entry.

Search text in Quick Access is local to the popup — it does not sync with the main window search field.

## Copy password

1. Select an entry (or leave the first match selected).
2. Press **↵**, or use the row’s copy button.
3. NativePass decrypts the entry, copies the **password** (first line) to the clipboard, shows a brief toast, then closes the popup after a short delay.

Clipboard auto-clear follows **Settings → General → Clipboard** (same as the main app). Decrypt failures stay in the footer; the popup stays open so you can retry or dismiss.

Only the password is copied this way — not username, URL, or OTP. Use **Open in NativePass** for the full entry.

## Open in the main window

**⌘O** or **Open in NativePass**:

- Closes Quick Access
- Activates the main window
- Selects **All** and the chosen entry (main-window search is cleared)

## App Lock

If NativePass is locked, Quick Access still opens and shows an unlock screen (Touch ID / device password). Success unlocks the **whole app**, then the normal search UI appears. Cancel or fail leaves the lock screen; you can try **Unlock** again or close the popup.

See [App Lock](app-lock.md).

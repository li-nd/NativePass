# App Lock

App Lock hides the NativePass UI behind macOS authentication (Touch ID or device password). It does **not** replace GPG: decrypting an entry still uses pinentry when your private key needs a passphrase. See [Setup](setup.md) and [Troubleshooting](troubleshooting.md).

## Enable and configure

Under **Settings → Security**:

| Setting | Behavior |
|---------|----------|
| **Require authentication** | Turns App Lock on or off. Enabling locks the UI immediately. Turning it off requires authentication. |
| **Lock after…** | Idle timeout: **1**, **3**, **5**, **15** (default), or **30** minutes. Changing the timeout requires authentication. |

Settings cannot be opened while the app is locked (the settings window is closed on lock).

## When the app locks

| Trigger | Auto-prompt on lock screen? |
|---------|-----------------------------|
| Idle longer than the configured timeout (checked while NativePass is active) | Yes — biometrics once |
| **Lock Now** (`⌃⌘L` or the app menu) | No — press **Unlock** yourself |
| App launch / relaunch with App Lock already enabled | Yes — biometrics once |

What does **not** lock NativePass:

- Hiding the app (**⌘H**)
- Switching to another app
- Putting the Mac to sleep / locking the screen (idle is only evaluated while NativePass’s scene is active)

**Lock Now** is disabled when App Lock is off or the UI is already locked.

## What happens on lock

- Main window shows the lock overlay (entry list and details are not visible).
- [Quick Access](quick-access.md) is closed if it was open.
- Settings windows are closed.
- In-memory entry metadata (username, URL, OTP flags) is cleared.
- A sensitive value still on the clipboard from NativePass is cleared.
- Sidebar folder, selected entry, and search query are **kept** so the UI can restore after unlock.
- Pass / GPG store files on disk are unchanged.

While locked, decrypt / edit / sync actions from the app are blocked.

## Unlock

### Main window

- After idle or launch lock, NativePass may prompt for Touch ID automatically (biometrics-only for that auto attempt).
- **Unlock** always allows Touch ID **or** your Mac login password.
- Cancel or failure leaves the lock screen; you can try again.

### Quick Access

Open **⌥⌘P** while locked: the popup shows its own unlock UI (same authentication). Success unlocks the **entire** app, then you can search and copy. Details: [Quick Access](quick-access.md).

### After unlock

Navigation (folder, selection, search) returns as it was. Decrypted contents are not kept across the lock — open an entry again to view or copy secrets.

## Limits

App Lock protects the NativePass UI in this process. It is not full-disk encryption and does not stop someone with access to your unlocked Mac from using `pass` in Terminal or reading `~/.password-store` if they can decrypt with your GPG key.

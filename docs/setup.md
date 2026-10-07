# Setup

## 1. Install NativePass

```bash
brew tap li-nd/apps
brew trust li-nd/apps
brew install --cask nativepass
```

Or download from [GitHub Releases](https://github.com/li-nd/NativePass/releases).  
Shared tap: [li-nd/homebrew-apps](https://github.com/li-nd/homebrew-apps).

!!! warning "Gatekeeper"
    Current builds are ad-hoc signed and **not notarized**. On first launch macOS may block the app — use **System Settings → Privacy & Security → Open Anyway**, or right-click the app → **Open**.

## 2. Install core tools

```bash
brew install pass gnupg gnu-getopt pinentry-mac
```

## 3. Initialize the password store

You can do this in Terminal:

```bash
gpg --list-secret-keys --keyid-format LONG
pass init YOUR_GPG_KEY_ID
```

Optional Git backing:

```bash
pass git init
# then add a remote and push as usual
```

Or in NativePass on first launch: **Create New Store…** (pick a path and GPG keys, optionally **Initialize Git**) or **Choose Existing Folder…**.

## 4. Configure pinentry (passphrase popup)

Without `pinentry-mac`, GPG may fail to prompt cleanly from the app.

Add this line to `~/.gnupg/gpg-agent.conf`:

```text
pinentry-program /opt/homebrew/bin/pinentry-mac
```

On Intel Homebrew, use:

```text
pinentry-program /usr/local/bin/pinentry-mac
```

Reload the agent:

```bash
gpgconf --kill gpg-agent
```

NativePass also shows this in **Settings → Security**:

![Security settings](screenshots/8-settings-security.png)

!!! note "App Lock vs GPG"
    **App Lock** protects the NativePass UI (Touch ID / device password).  
    **GPG decryption** still uses pinentry when your private key needs a passphrase.

## 5. Open NativePass

1. Launch NativePass from Applications (or build from Xcode).
2. Open **Settings → Diagnostics** and confirm pass, GPG, and pinentry look healthy.
3. Manage stores under **Settings → Store** (add existing, create, switch, change encryption keys).

### Multiple stores

NativePass can keep several store folders (only paths are saved). The active store sets `PASSWORD_STORE_DIR` for all pass/GPG operations.

- **Settings → Store** — list with per-store **Use** / remove (optional delete files from disk), **Add Existing…**, **Create Store…**, **Change Encryption Keys…**
- **Store** menu — switch active store (**⌃⌘[** / **⌃⌘]**, **⌃⌘1–9**), create or add existing, open Store Settings

### Encryption keys

`pass init` selects GPG recipients for new/updated entries. NativePass wraps this for:

- Creating a store
- **Change Encryption Keys…** on the store root (re-encrypts the whole store)
- **Change Keys…** on a folder that has (or will get) its own `.gpg-id` (`pass init -p`)

Folders with a distinct `.gpg-id` show a people badge in the sidebar. Entry detail shows **Encrypted for:** based on the nearest `.gpg-id`.

![General settings](screenshots/7-settings-general.png)

# Requirements

NativePass is a GUI around tools you install separately.

## Install the app

```bash
brew tap li-nd/apps
brew trust li-nd/apps
brew install --cask nativepass
```

Or use [GitHub Releases](https://github.com/li-nd/NativePass/releases). Tap: [li-nd/homebrew-apps](https://github.com/li-nd/homebrew-apps). Requires **macOS Tahoe** or newer.

## Required

| Tool | Install | Purpose |
|------|---------|---------|
| **pass** | `brew install pass` | Password store CLI |
| **GnuPG** | `brew install gnupg` | Encrypt / decrypt entries |
| **gnu-getopt** | `brew install gnu-getopt` | Needed by Homebrew `pass` on macOS |

Initialize a store (once):

```bash
pass init YOUR_GPG_KEY_ID
```

Default store path: `~/.password-store`

## Recommended

| Tool | Install | Purpose |
|------|---------|---------|
| **pinentry-mac** | `brew install pinentry-mac` | macOS passphrase / Touch ID prompts for GPG |
| **git** | (usually present) | Sync the store |

## Optional

| Tool | Install | Purpose |
|------|---------|---------|
| **pass-otp** | `brew install pass-otp` | TOTP codes in NativePass |
| **oathtool** | `brew install oath-toolkit` | Used by some OTP workflows |
| **qrencode** | `brew install qrencode` | QR helpers for `pass-otp` |

See [Setup](setup.md) for pinentry configuration and [Plugins](plugins.md) for OTP details.

<div class="np-hero" markdown="0">
  <img src="logo.png" alt="NativePass" width="200">
</div>

# NativePass

Native macOS client for [pass](https://www.passwordstore.org/) — browse nested folders, copy passwords, show TOTP codes, and sync with Git.

![Main window](screenshots/1-main.png)

## Features

- Nested folders and [fuzzy path search](search.md)
- Custom fields and password generator
- TOTP verification codes (with `pass-otp`)
- Git Pull / Push
- [App Lock](app-lock.md) with Touch ID
- [Quick Access](quick-access.md) popup (`⌥⌘P`)

## Quick start

1. Install NativePass:
   ```bash
   brew tap li-nd/apps
   brew trust li-nd/apps
   brew install --cask nativepass
   ```
   Or download from [GitHub Releases](https://github.com/li-nd/NativePass/releases). Tap: [homebrew-apps](https://github.com/li-nd/homebrew-apps).
2. Install [requirements](requirements.md)
3. Follow [setup](setup.md) (store + pinentry)
4. Optional: install [plugins](plugins.md)
5. Open NativePass and check **Settings → Diagnostics**

## Docs

| Page | Topic |
|------|--------|
| [Requirements](requirements.md) | Homebrew packages |
| [Setup](setup.md) | `pass init`, pinentry, Touch ID |
| [Plugins](plugins.md) | `pass-otp` and more |
| [Usage](usage.md) | Browse, create, edit, sync |
| [Search](search.md) | Fuzzy path search |
| [Quick Access](quick-access.md) | Global hotkey popup |
| [App Lock](app-lock.md) | Idle lock and Touch ID |
| [Troubleshooting](troubleshooting.md) | Diagnostics and common issues |

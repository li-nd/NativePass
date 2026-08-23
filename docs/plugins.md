# Plugins

NativePass discovers `pass` extensions automatically. Enable extensions is handled for you when the app runs `pass`.

## pass-otp (recommended)

Install:

```bash
brew install pass-otp
```

Enables:

- TOTP codes in the entry detail view
- **Verification Codes** in the sidebar
- **Set Up Code…** when creating or editing an entry

![Diagnostics with pass-otp](screenshots/10-settings-diagnostics.png)

Check status anytime in **Settings → Diagnostics → Plugins**.

## Other known plugins

| Plugin | Install | In NativePass |
|--------|---------|----------------|
| **pass-otp** | `brew install pass-otp` | Full UI support |
| **pass-import** | see [pass-import](https://github.com/roddhjav/pass-import) | Detected; import wizard not implemented yet |
| **pass-update** | see [pass-update](https://github.com/roddhjav/pass-update) | Detected; shown in diagnostics |

Unknown `*.bash` extensions under the system or user extensions directory still appear in Diagnostics.

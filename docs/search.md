# Search

NativePass searches **entry paths only** — the same names you see in the store listing (for example `Work/Google/account`), without decrypting `.gpg` files.

The same rules apply in the [main window](usage.md) and in [Quick Access](quick-access.md).

## What is searched

| Included | Not included |
|----------|----------------|
| Full path string (folders + entry name) | Password and other decrypted fields |
| Case- and diacritic-insensitive matching | `username`, `url`, notes, OTP secrets |
| Spaces inside path names (as characters in the path) | Anything that requires opening an entry |

Username and similar fields appear in the UI only after an entry has been decrypted in this session; they are never part of the search index.

## How matching works

Search is **fuzzy** (similar in spirit to tools like `fzf`):

1. The query is split on whitespace into **tokens**.
2. **Every** token must match the path (AND).
3. A token matches if its characters appear **in order** in the path — not necessarily next to each other (`goo` matches `google`).
4. Results are ranked so stronger matches rise to the top (contiguous runs, matches at the start of a path segment after `/`, `-`, `_`, `.`, or a space, and shorter paths).

Spaces in the query separate tokens; they are not a literal space you must find in the path. Paths that contain spaces still work: query `my bank` can match `My Bank/login` because both tokens match that one string.

| Query | Example match | Why |
|-------|----------------|-----|
| `google` | `Work/Google/mail` | Subsequence / substring in the path |
| `goo ac` | `google/account` | Token `goo` → `google`, token `ac` → `account` |
| `wk gmail` | `Work/Google/gmail` | Characters in order across segments |
| `bank` | `My Bank/checking` | Path may contain spaces; still one searchable string |

## Where search appears

- **Main window** — macOS search field in the detail column. While the query is non-empty, the list shows matches from the **entire store**; the sidebar category (folder / All / Verification Codes) is ignored. Clear the query to browse the selected category again. With an empty query, Name/Path sort applies; with a query, order is by match relevance.
- **Quick Access** (`⌥⌘P`) — same fuzzy rules over the whole store (first 50 matches in the list).

Opening an entry from Quick Access into the main window clears the main-window search and selects **All**.

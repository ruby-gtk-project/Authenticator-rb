# Component inventory — Authenticator (upstream `origin/master` vs `ruby` port)

Upstream is pure PyGObject (GTK3), with **no `.blp`/`.ui` files** — every widget
is built in code via `_build_widgets()` methods, same as the Ruby house style.
Non-Python sources checked: `data/com.github.bilelmoussaoui.Authenticator.gschema.xml`,
`data/com.github.bilelmoussaoui.Authenticator.appdata.xml.in`,
`data/com.github.bilelmoussaoui.Authenticator.desktop.in`,
`data/com.github.bilelmoussaoui.Authenticator.gresource.xml`, `data/data.json`,
`data/style.css`, `po/` (14 `LINGUAS` catalogues + `.pot`), and the
`search-provider/` GNOME Shell search-provider service files.

The `ruby` branch already has a `lib/*.rb` file for every upstream widget file
below (38 files, 4654 lines) — this is a mature port, not a fresh scaffold.
Entries marked **exists** have a same-named/mapped file already in `lib/`;
the inventory below is for verifying parity, not creating new files.

User-meeting order: Window → HeaderBar → SearchBar → AccountsWidget (list,
row, provider grouping) → ActionsBar → EmptyAccountsList → AddAccountWindow →
EditAccountWindow → SettingsWindow (+ PasswordWindow) → GPG backup windows →
AboutDialog → Application (menu/actions) → file choosers.

## Application (app-level unit)

| Upstream | `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `Authenticator/application.py` | `lib/application.rb` | app class (actions, menu, CSS load, night-mode) | yes |
| `Authenticator/widgets/utils.py` (file choosers) | `lib/file_choosers.rb` | helper functions → `import_json`/`export_json`/`import_pgp_json`/`export_pgp_json`/`open_directory` | yes |
| `search-provider/authenticator-search-provider.py.in` | `lib/shell_search_provider.rb` | GNOME Shell search provider D-Bus service | yes |
| `data/com.github.bilelmoussaoui.Authenticator.gschema.xml` | `lib/settings.rb` | GSettings schema (`window-position`, `night-mode`, `is-maximized`, `gpg-location`) | yes |
| `data/data.json` | consumed in `lib/account_config.rb` / `lib/provider_image.rb` | provider-name→logo data | yes |
| `Authenticator/application.py` `__generate_menu` | `lib/primary_menu.rb` | `Gio.Menu` (Backup→Restore/Backup submenus, Settings, About, Quit) + `app.*` actions | yes |

## `Authenticator/widgets/window.py` — main application window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ApplicationWindow` | 1 | — | `changed`(bool, custom), `key-press-event` | top-level; icon name, 550×600, position/maximized restore |
| `Gtk.Box` (main container, vertical) | 1 | — | — | |
| `Gtk.Stack` | 1 | — | — | pages: `accounts-list`, `empty-accounts-list` |
| `Gtk.Box` (accounts-list page, vertical) | 1 | — | — | holds SearchBar + AccountsWidget + ActionsBar |

→ `lib/window.rb` (exists, 211 lines). Composes `HeaderBar`, `AccountsWidget`,
`SearchBar`, `ActionsBar`, `EmptyAccountsList`. Owns `toggle_select`,
`add_account`, `update_view`, window-state save/restore.

## `Authenticator/widgets/headerbar.py` — title bar + mode switching

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.HeaderBar` | 1 | `selection-mode` (dynamic, in SELECT state) | — | `show-close-button` toggled per state |
| `Gtk.ToggleButton` (search) | 1 | — | bound bidirectionally to `SearchBar.search-mode-enabled` | icon `system-search-symbolic` |
| `Gtk.Button` (add) | 1 | — | `clicked`→`Window.add_account` | icon `list-add-symbolic` |
| `Gtk.Button` (settings/menu) | 1 | — | `clicked`→`toggle_popover` | icon `open-menu-symbolic` |
| `Gtk.Button` (select) | 1 | — | `clicked`→`Window.toggle_select` | icon `object-select-symbolic` |
| `Gtk.Button` (cancel) | 1 | — | `clicked`→`Window.toggle_select` | label "Cancel"; bound to ActionsBar visibility |
| `Gtk.Popover` | 1 (lazy) | — | — | built from `Gio.Menu` via `generate_popover_menu` |

States: `HeaderBarState.{EMPTY,NORMAL,SELECT}` drive which buttons show/hide
and the title text ("Click on items to select them" in SELECT).
→ `lib/header_bar.rb` (exists, 155 lines).

## `Authenticator/widgets/search_bar.py` — inline search

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.SearchBar` | 1 | — | `key-press-event` (via window) toggles reveal | `show-close-button` true |
| `Gtk.SearchEntry` | 1 | — | `search-changed`→filter | width 28 chars; bound to each `AccountsList`'s filter func |

Filter matches on username or provider (case-insensitive). → `lib/search_bar.rb` (exists, 64 lines).

## `Authenticator/widgets/actions_bar.py` — bulk-delete bar

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ActionBar` | 1 | — | — | hidden by default (`no-show-all`) |
| `Gtk.Button` (delete) | 1 | — | `clicked`→`AccountsWidget.delete_selected` | disabled until ≥1 row selected |

→ `lib/actions_bar.rb` (exists, 56 lines).

## `Authenticator/widgets/accounts/list.py` — three components in one file

### `AccountsWidget` — one instance, owns the whole list area

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (vertical) | 1 | `accounts-widget` | `changed`, `selected-rows-changed`(int) | top container |
| `Gtk.ProgressBar` | 1 | — | — | OTP countdown, driven by `AccountsManager#counter_updated` |
| `Gtk.Box` (accounts-container, vertical) | 1 | `accounts-container` | — | holds one `ProviderWidget` per provider |
| `Gtk.ScrolledWindow` | 1 | — | — | wraps accounts-container |

Repeater: one `ProviderWidget` per distinct provider string, built on first
`append()` for that provider and torn down when its list empties
(`_clean_unneeded_providers_widgets`). → `lib/accounts_widget.rb` (exists, 192 lines).

### `ProviderWidget` — one provider group header + its rows

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (vertical) | 1 | — | — | |
| `Gtk.Box` (provider header, horizontal) | 1 | — | — | |
| `Gtk.Label` (provider name) | 1 | `provider-lbl` | — | |
| `Gtk.Image` | 1 | — | — | provider logo via `load_pixbuf_from_provider` |

→ `lib/provider_widget.rb` (exists, 56 lines).

### `AccountsList` — one `Gtk.ListBox` per provider

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBox` | 1 | `accounts-list` | `selected-count-rows-changed`(int), `account-deleted` | selection mode NONE; houses N `AccountRow`s |

→ `lib/accounts_list.rb` (exists, 123 lines).

### `EmptyAccountsList` — empty state

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (vertical) | 1 | — | — | centered, 36px border |
| `Gtk.Image` | 1 | — | — | `dialog-information-symbolic`, DIALOG size |
| `Gtk.Label` | 1 | — | — | "There are no accounts yet…" |

→ `lib/empty_accounts_list.rb` (exists, 27 lines).

## `Authenticator/widgets/accounts/row.py` — two components

### `ActionsBox` (per-row action buttons)

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (horizontal) | 1 | — | — | |
| `Gtk.Button`→`ActionButton` (copy) | 1 | — | `clicked`→copy OTP | icon `edit-copy-symbolic` |
| `Gtk.Button`→`ActionButton` (edit) | 1 | — | `clicked`→open `EditAccountWindow` | icon `document-edit-symbolic` |

### `AccountRow` — one account entry

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` | 1 | `account-row` | `on_selected` (custom) | |
| `Gtk.Box` (horizontal) | 1 | — | — | |
| `Gtk.CheckButton` | 1 | `account-row-checkbtn` | `toggled`→emit `on_selected` | hidden outside select mode |
| `Gtk.Label` (username) | 1 | `username` | — | ellipsized end, tooltip = username |
| `ActionsBox` (composite) | 1 | — | — | copy/edit, see above |
| `Gtk.Label` (OTP pin) | 1 | `token-label` | — | shows `??????` + tooltip if generation fails; updated on `otp_updated` |

→ `lib/account_row.rb` (exists, 192 lines; `lib/actions_bar.rb` is the
*other* ActionsBar component — the row-level `ActionsBox` should be checked
as living inside `account_row.rb`, not confused with it).

## `Authenticator/widgets/accounts/add.py` — two components

### `AddAccountWindow`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | — | `key_press_event` (Esc→close, Ctrl+Q→scan) | 400×600, centered on parent |
| `Gtk.HeaderBar` | 1 | — | — | `show-close-button` false |
| `Gtk.Button` (add) | 1 | `suggested-action` | `clicked`→create account | disabled until valid |
| `HeaderBarButton` (scan QR) | 1 (conditional) | — | `clicked`→`scan_qr` | only if `Application.USE_QRSCANNER` and zbar available |
| `Gtk.Button` (close) | 1 | — | `clicked`→destroy | |

→ `lib/add_account_window.rb` (exists, 169 lines).

### `AccountConfig` — the add/edit form, reused by both windows

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (vertical) | 1 | — | `changed`(bool) | |
| `Gtk.Image` (logo) | 1 | — | — | from provider name, 96px |
| `Gtk.Entry` (username) | 1 | `error` (dynamic, invalid) | `changed`→validate | |
| `Gtk.ComboBox` (provider, with entry) | 1 | `error` (dynamic) | `changed`→logo update + validate | `Gtk.EntryCompletion` backed by `data.json` |
| `Gtk.Entry` (token) | 1 (add mode only) | `error` (dynamic) | `changed`→validate | hidden/masked, OTP-secret validated |
| `Gd.Notification` | 1 (transient) | — | `dismissed` | QR-scan error / zbar-missing messages |

→ `lib/account_config.rb` (exists, 275 lines — largest widget file; confirm
QR-scan notification path is present).

## `Authenticator/widgets/accounts/edit.py` — `EditAccountWindow`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | — | `updated`(str,str) custom, `key_press_event` (Esc) | 400×600 |
| `Gtk.HeaderBar` | 1 | — | — | title = "Edit {user} - {provider}" |
| `Gtk.Button` (save) | 1 | `suggested-action` | `clicked`→save | |
| `Gtk.Button` (close) | 1 | — | `clicked`→destroy | |
| `AccountConfig` (composite, edit mode) | 1 | — | — | reuses add.py's form |

→ `lib/edit_account_window.rb` (exists, 134 lines).

## `Authenticator/widgets/settings.py` — four components

### `ClickableSettingsBox`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.EventBox` | 1 | — | `button-press-event` (caller-supplied) | |
| `Gtk.Box` (vertical) | 1 | `settings-box` | — | |
| `Gtk.Label` ×2 | 2 | `settings-box-main-label`, `settings-box-secondary-label` | — | main + secondary text |

→ `lib/clickable_settings_box.rb` (exists, 49 lines).

### `SwitchSettingsBox`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (horizontal) | 1 | `settings-box` | `changed`(bool) custom | |
| `Gtk.Label` ×2 | 2 | `settings-box-main-label`, `settings-box-secondary-label` | — | |
| `Gtk.Switch` | 1 | — | toggled via `__on_toggled` | writes a GSettings key named by `schema` arg |

→ `lib/switch_settings_box.rb` (exists, 48 lines).

### `SettingsBoxWithEntry`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (horizontal) | 1 | `settings-box` | — | |
| `Gtk.Label` | 1 | `settings-box-main-label` | — | |
| `Gtk.Entry` | 1 | `error` (dynamic) | `changed`→validate (caller-supplied) | optional password visibility off |

→ `lib/settings_box_with_entry.rb` (exists, 62 lines).

### `PasswordWindow`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | — | — | modal, 500×400, fixed, 36px border |
| `Gtk.HeaderBar` | 1 | — | — | title "Backup Password" |
| `Gtk.Button` (save) | 1 | `suggested-action` | `clicked`→apply | disabled until all fields valid |
| `SettingsBoxWithEntry` (old password) | 1 (conditional: only if a backup password already exists) | — | — | |
| `SettingsBoxWithEntry` (password) | 1 | — | — | |
| `SettingsBoxWithEntry` (repeat password) | 1 | — | — | |

→ `lib/password_window.rb` (exists, 158 lines).

### `SettingsWindow`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | — | — | transient for main window, 600×600, centered |
| `Gtk.HeaderBar` | 1 | — | — | custom title = stack switcher |
| `Gtk.StackSwitcher` + `Gtk.Stack` | 1 each | `settings-main-container` (stack) | — | pages: Appearance, Behaviour, Backup |
| `SwitchSettingsBox` (dark theme) | 1 | — | `changed`→toggle `gtk-application-prefer-dark-theme` | Appearance page |
| `ClickableSettingsBox` (clear database) | 1 | — | `button-press-event`→`__on_clear_database_clicked` | Behaviour page |
| `Gd.Notification` | 1 (transient) | — | `dismissed`→actually clears DB/keyring/accounts | 5s undo window |
| `Gtk.Label` + `Gtk.Button` (undo) inside notification | 1 each | — | `clicked`→hide notification | |
| `ClickableSettingsBox` (GPG keys location) | 1 | — | `button-press-event`→open directory chooser | Backup page |

→ `lib/settings_window.rb` (exists, 205 lines). Verify the 5-second
undo-able clear-database flow (via `Gd.Notification`) is reproduced — this is
easy to drop silently in a port since it is not a plain dialog.

## `Authenticator/widgets/backup/gnupg.py` — two components

### `GPGRestoreWindow`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | — | — | 400×200, centered on parent |
| `Gtk.HeaderBar` | 1 | — | — | title "GPG paraphrase" |
| `Gtk.Button` (import) | 1 | `suggested-action` | `clicked`→decrypt+import | |
| `SettingsBoxWithEntry` (paraphrase) | 1 | — | — | masked entry |
| `Gd.Notification` | 1 (transient) | — | — | decrypt-failure message |

→ `lib/gpg_restore_window.rb` (exists, 165 lines).

### `FingprintPGPWindow`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | — | `selected`(str) custom | 600×600, centered on parent, title "GPG fingerprint" |
| `Gtk.Label` ×2 (section headers) | 2 | `gpg-key-lbl` | — | "Public keys" / "Private keys" |
| `ClickableSettingsBox` (repeater, one per key) | N | — | `button-press-event`→emit `selected` with fingerprint | uid as main label, fingerprint as secondary |

→ `lib/gpg_fingerprint_window.rb` (exists, 115 lines).

## `Authenticator/widgets/about.py.in` — `AboutDialog`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.AboutDialog` | 1 | — | — | modal; authors, artists, GPL-3.0 license, version from `@VERSION@` substitution, website link |

→ `lib/about_dialog.rb` (exists, 46 lines).

## `Authenticator/widgets/utils.py` — file choosers (no widget tree, but user-facing)

| Function | Widget | Notes |
|---|---|---|
| `import_json` / `export_json` | `Gtk.FileChooserNative` | JSON mimetype filter |
| `import_pgp_json` / `export_pgp_json` | `Gtk.FileChooserNative` | `application/pgp-encrypted` filter |
| `open_directory` | `Gtk.FileChooserNative` (SELECT_FOLDER) | shows hidden files; used by GPG-location setting |

→ `lib/file_choosers.rb` (exists, 118 lines).

## Non-widget but user-facing surfaces

| Upstream file | Port | Kind | Exists |
|---|---|---|---|
| `data/com.github.bilelmoussaoui.Authenticator.appdata.xml.in` | — (packaging metadata, no `lib/` mapping) | AppStream metadata | n/a — not a `lib/` component |
| `data/com.github.bilelmoussaoui.Authenticator.desktop.in` | — | desktop launcher entry | n/a |
| `data/style.css` | consumed by `lib/application.rb`'s CSS loader | stylesheet (class names referenced above) | yes (loader present; confirm all classes from the tables above exist in the port's CSS/resource) |
| `data/data.json` (provider name→logo map) | `lib/provider_image.rb` / `lib/account_config.rb` | data table | yes |
| `po/*.po` (14 locales) + `po/Authenticator.pot` | `locale/` | translation catalogues | present as `locale/` dir — verify catalogue count/coverage in a dedicated translation-parity pass |
| `search-provider/authenticator-search-provider.py.in` + `.service.in` + `.ini` | `lib/shell_search_provider.rb` | GNOME Shell search provider | yes |

## Models (non-widget, referenced by the above; not in scope of this UI survey but needed by every window above)

`Authenticator/models/{account,accounts_manager,backup,clipboard,database,
gnupg,keyring,logger,otp,qr_reader,screenshot,settings}.py` all have
corresponding `lib/*.rb` files already (`account.rb`, `accounts_manager.rb`,
`backup.rb`, `clipboard.rb`, `database.rb`, `gpg.rb`, `keyring.rb`,
`logger.rb`, `otp.rb`, `qr_reader.rb`, `screenshot.rb`, `settings.rb`).

## Summary

- **38 upstream widget/app/model-adjacent source units identified; all 38 have a
  same-shaped file already present on `ruby`.** No missing `lib/*.rb` files were
  found — this port is at or near structural completion.
- This survey did **not** modify any app code, per instructions. It is a
  parity-verification map, not a gap list: every `exists: yes` above still
  needs `component-parity` to confirm widget/CSS-class/signal-level fidelity,
  not just file presence. Flagged for closer parity review above:
  - `lib/settings_window.rb` — the 5s undo-able "clear database" `Gd.Notification` flow.
  - `lib/account_config.rb` — the QR-scanner notification path and the
    zbar-availability conditional button.
  - `lib/header_bar.rb` — the `selection-mode` CSS class and three-state
    button visibility matrix (EMPTY/NORMAL/SELECT).
  - Translation catalogue coverage (`po/LINGUAS`: ar, da, de, es, fr, hu, id,
    nb_NO, nl, nl_BE, pl, sr, sr@latin, sv) against the port's `locale/` — left
    to a dedicated `translation-parity` pass.

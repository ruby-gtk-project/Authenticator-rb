# Authenticator — upstream component inventory

Upstream: `origin/master` — Authenticator 3.x, **Python + PyGObject, GTK 3**.
Port: the `ruby` branch, GTK4 + Libadwaita, house style per `.claude/skills/ruby-gtk`.

Survey facts that shape everything below:

- **No `.ui` and no `.blp` files anywhere.** Every widget is built in Python
  source, so the declarative shortcut in the `component-identification` skill
  does not apply — the inventory comes from reading all 13 widget files.
- **GTK 3 upstream.** A large part of the port is not translation but
  replacement: `Gd.Notification`, `Gtk.EventBox`, `Gtk.ComboBox` with entry,
  `Gtk.EntryCompletion`, `Gtk.FileChooserNative#run`, `Gdk.Screen` CSS,
  window-position restore and `Gtk.SearchBar#handle_event` are all gone in
  GTK4. See **Blockers**.
- **The port is still the scaffold.** `lib/` holds exactly three files:
  `lib/authenticator.rb`, `lib/authenticator/application.rb` (an
  `Adw::StatusPage` saying "The Ruby port has not been written yet.") and
  `lib/authenticator/rb/version.rb`. **No user-facing component exists yet.**
- Naming follows the pilot (`gnome-contacts-rb`): components are flat
  `lib/<thing>.rb`, only the application class sits under
  `lib/authenticator/`.

Totals: **24 user-facing components** across 10 upstream widget files, plus 11
supporting model files, 1 stylesheet, 1 GSettings schema, 1 GResource manifest,
1 provider-logo data file and a 14-language `po/` catalogue (58 msgids). One
exists in the port (the application class, as a placeholder); 23 do not.

---

## Authenticator/application.py — the application: actions, menu, CSS, about

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Application` | 1 | — | `startup`, `activate` | id `com.github.bilelmoussaoui.Authenticator`, `FLAGS_NONE`; prgname + app name set to `Authenticator` |
| `Gio.Menu` | 1 | — | — | two sections; see the menu component below |
| `Gtk.CssProvider` | 1 | — | — | loads `resource:///com/github/bilelmoussaoui/Authenticator/style.css` at `STYLE_PROVIDER_PRIORITY_USER` onto `Gdk.Screen` |
| `Gtk.Settings` | 1 | — | — | `gtk-application-prefer-dark-theme` from the `night-mode` key |

**Actions installed (all `app.`, none parameterised, all built from a dict —
the scan's `action` stream misses every one):**
`app.about`, `app.quit`, `app.settings`, `app.import_json`,
`app.import_pgp_json`, `app.export_json`, `app.export_pgp_json`.

Behaviour on activate: adds the resource path to the icon theme, takes the
singleton `Window`, sets the menu on the header bar, connects `delete-event`
to quit, `show_all` + `present`. Quit clears the clipboard first (security).

→ `lib/authenticator/application.rb` — **exists** (placeholder only: window +
toolbar view + header bar + status page; no actions, no menu, no CSS, no
dark-mode wiring).

## Authenticator/application.py (`__generate_menu`) — the primary menu

| Item | Action | Section |
|---|---|---|
| `from a plain-text JSON file` | `app.import_json` | submenu *Restore* |
| `from an OpenPGP-encrypted JSON file` | `app.import_pgp_json` | submenu *Restore* |
| `in a plain-text JSON file` | `app.export_json` | submenu *Backup* |
| `in an OpenPGP-encrypted JSON file` | `app.export_pgp_json` | submenu *Backup* |
| `Settings` | `app.settings` | main section |
| `About` | `app.about` | main section |
| `Quit` | `app.quit` | main section |

Section 1 holds the two submenus; section 2 holds the three main items. In
GTK3 it is shown through `Gtk.Popover.new_from_model` on the header bar's
settings button with `width_request = 200`.

→ `lib/primary_menu.rb` — **missing** (in the port this becomes an
`Adw::HeaderBar` + `Gtk::MenuButton` with a `Gio::Menu` model).

## Authenticator/widgets/window.py — the main window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ApplicationWindow` | 1 | — | `changed` (own, `bool`), `key-press-event`, `delete-event` | singleton `get_default`; 550×600; icon `com.github.bilelmoussaoui.Authenticator` |
| `Gtk.Box` (vertical) | 2 | — | — | main container, accounts-list container |
| `Gtk.Stack` | 1 | — | — | children `accounts-list` and `empty-accounts-list` |

Composites used: `HeaderBar` (titlebar), `SearchBar`, `AccountsWidget`,
`ActionsBar`, `EmptyAccountsList`.

Wiring that is part of the component: `select_btn`/`cancel_btn` → `toggle_select`,
`add_btn` → `add_account`, `accounts_widget "changed"` → `update_view`,
`actions_bar.delete_btn` → `accounts_widget.delete_selected`,
`accounts_widget "selected-rows-changed"` → `actions_bar.on_selected_rows_changed`,
and two bidirectional property bindings tying `ActionsBar#visible` /
`#no_show_all` to `header_bar.cancel_btn`.

States: **empty** (`Database#count == 0` → `empty-accounts-list` page +
`HeaderBarState.EMPTY`), **normal**, **select**.
Window state persisted via GSettings `window-position` and `is-maximized`.

→ `lib/window.rb` — **missing**.

## Authenticator/widgets/headerbar.py — the header bar and its three states

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.HeaderBar` | 1 | `selection-mode` (added in SELECT, removed on leaving) | — | `show_close_button` toggled with state; title `Click on items to select them` in SELECT, `""` otherwise |
| `Gtk.ToggleButton` (`HeaderBarToggleButton`) | 1 | — | `toggled` via the search-mode binding | search; icon `system-search-symbolic`, tooltip `Search` |
| `Gtk.Button` (`HeaderBarButton`) | 3 | — | `clicked` | add (`list-add-symbolic`, `Add a new account`), settings (`open-menu-symbolic`, `Settings`), select (`object-select-symbolic`, `Selection mode`) |
| `Gtk.Button` | 1 | — | `clicked` → `toggle_select` | `Cancel`, hidden outside SELECT |
| `Gtk.Box` (horizontal) | 2 | — | — | left (add) and right (search, select, cancel, settings) |
| `Gtk.Popover` | 1 | — | — | `new_from_model(settings_btn, menu)`, `width_request = 200` |
| `Gtk.Image` / `Gio.ThemedIcon` | 4 / 4 | — | — | one per icon button |

`HeaderBarState`: `EMPTY = 0`, `NORMAL = 2`, `SELECT = 3`. Per-state visibility
is the component's whole behaviour — EMPTY shows add + settings only; SELECT
shows search + cancel, adds `selection-mode`, hides close button; NORMAL shows
all four.

→ `lib/header_bar.rb` — **missing** (`HeaderBarBtn`/`HeaderBarButton`/
`HeaderBarToggleButton` fold into this file; GTK4 header bars set the title
widget rather than a title string, and the popover becomes a `Gtk::MenuButton`).

## Authenticator/widgets/search_bar.py — the search bar

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.SearchBar` | 1 | — | `key-press-event` forwarded from the window via `handle_event` | `show_close_button = true`; `search-mode-enabled` bound bidirectionally to the header bar's search toggle |
| `Gtk.SearchEntry` | 1 | — | `search-changed` → `set_filter_func` | 28 chars wide; `connect_entry` |

Filter: case-insensitive substring over `row.account.username` and
`row.account.provider`, applied to **every** `AccountsList` in
`AccountsWidget#accounts_lists` (a repeater over providers).

→ `lib/search_bar.rb` — **missing** (`handle_event` is gone in GTK4 —
`set_key_capture_widget(window)` instead).

## Authenticator/widgets/actions_bar.py — the selection-mode action bar

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ActionBar` | 1 | — | — | singleton; starts hidden (`visible = false`, `no_show_all = true`) |
| `Gtk.Button` | 1 | — | `clicked` → `AccountsWidget#delete_selected` | `Delete`, insensitive until ≥1 row is selected |

→ `lib/actions_bar.rb` — **missing**.

## Authenticator/widgets/accounts/list.py — AccountsWidget: the accounts view

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (vertical) | 1 | `accounts-widget` | own `changed`, `selected-rows-changed` (`int`) | singleton |
| `Gtk.ProgressBar` | 1 | — | fed by `AccountsManager "counter_updated"` | fraction = counter / 30; tooltip `The One-Time Passwords expires in {} seconds` |
| `Gtk.ScrolledWindow` | 1 | — | — | `add_with_viewport` (GTK3-only call) |
| `Gtk.Box` (vertical) | 1 | `accounts-container` | — | holds one `ProviderWidget` per provider |

**Repeater:** one `ProviderWidget` per distinct provider, re-sorted
case-insensitively by provider on every append. Empty provider groups are
collected in `_to_delete` and pruned after a delete or a provider change.

→ `lib/accounts_widget.rb` — **missing**.

## Authenticator/widgets/accounts/list.py — ProviderWidget: one provider group

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (vertical) | 1 | — | — | header row + its `AccountsList` |
| `Gtk.Box` (horizontal) | 1 | — | — | logo + label |
| `Gtk.Label` | 1 | `provider-lbl` | — | provider name, `halign START` |
| `Gtk.Image` | 1 | — | — | pixbuf from `load_pixbuf_from_provider(provider)` (48px) |

→ `lib/provider_widget.rb` — **missing**.

## Authenticator/widgets/accounts/list.py — AccountsList: rows for one provider

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBox` | 1 | `accounts-list` | own `selected-count-rows-changed` (`int`), `account-deleted` | `selection_mode NONE`; `AccountsListState` `NORMAL = 0` / `SELECT = 1` |

**Repeater:** one `AccountRow` per account. `set_state` shows/hides every
row's check button; `delete_selected` removes each checked account
(`account.remove()`) and returns to NORMAL.

→ `lib/accounts_list.rb` — **missing**.

## Authenticator/widgets/accounts/list.py — EmptyAccountsList: the empty state

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (vertical) | 1 | — | — | singleton; border 36, centred both axes |
| `Gtk.Image` | 1 | — | — | `dialog-information-symbolic.symbolic` at `IconSize.DIALOG` |
| `Gtk.Label` | 1 | — | — | `There are no accounts yet…` |

→ `lib/empty_accounts_list.rb` — **missing** (an `Adw::StatusPage` is the
GTK4-era shape).

## Authenticator/widgets/accounts/row.py — AccountRow: one account

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` | 1 | `account-row` | own `on_selected` | holds its `Account`; listens to `account "otp_updated"` |
| `Gtk.CheckButton` | 1 | `account-row-checkbtn` | `toggled` → emits `on_selected` | hidden outside SELECT (`no_show_all = true`) |
| `Gtk.Box` | 4 | — | — | row container (h, spacing 6), info (v), otp (v), plus the actions box |
| `Gtk.Label` (username) | 1 | `username` | — | ellipsize END, `halign START`, tooltip = username |
| `Gtk.Label` (pin) | 1 | `token-label` | — | the OTP, or `??????` with tooltip `Couldn't generate the secret code` |

`ActionsBox` (same file, folds into the port file):

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (horizontal) | 1 | — | — | `valign CENTER` |
| `Gtk.Button` (`ActionButton`) | 2 | — | `clicked` | copy (`edit-copy-symbolic`, `Copy`) → `account.copy_pin`; edit (`document-edit-symbolic`, `Edit`) → opens `EditAccountWindow` |

Note the stylesheet defines `.account-name` and `.counter-label`, which no
source applies — dead CSS. The row uses `.username` and `.token-label`.

→ `lib/account_row.rb` — **missing**.

## Authenticator/widgets/accounts/add.py — AddAccountWindow

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | — | `key-press-event` | 400×600, centred on parent, transient for the main window |
| `Gtk.HeaderBar` | 1 | — | — | title `Add a new account`, no close button |
| `Gtk.Button` (add) | 1 | `suggested-action` | `clicked` → `_on_add` | `Add`, insensitive until the config validates |
| `Gtk.Button` (close) | 1 | — | `clicked` → destroy | `Close`, packed start |
| `Gtk.Button` (`HeaderBarButton`, scan) | 1 | — | `clicked` → `account_config.scan_qr` | `qrscanner-symbolic`, `Scan QR code`; **conditional** — only when `Application.USE_QRSCANNER` and `XDG_CURRENT_DESKTOP == gnome` |

Keyboard: `Escape` closes; `Ctrl` (+`MOD2`) + `q` triggers the QR scan.
On add: creates the `Account`, registers it with `AccountsManager`, appends it
to `AccountsWidget`, closes.

→ `lib/add_account_window.rb` — **missing**.

## Authenticator/widgets/accounts/add.py — AccountConfig: the account form

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (vertical) | 2 | — | own `changed` (`bool`) | outer + inner container, border 36 |
| `Gtk.Image` | 1 | — | — | provider logo at 96px, reloaded on every provider change |
| `Gtk.Entry` (username) | 1 | `error` (dynamic, when empty) | `changed` → `_validate` | placeholder `Account name` |
| `Gtk.ComboBox` with entry | 1 | `error` (dynamic, when empty) | `changed` → `_on_provider_changed` | over a `Gtk.ListStore(str, str)`; child entry placeholder `Provider` |
| `Gtk.EntryCompletion` | 1 | — | — | same store, text column 0 |
| `Gtk.Entry` (token) | 1 | `error` (dynamic, when empty or not a valid base32 TOTP secret) | `changed` → `_validate` | placeholder `Secret token`, `visibility = false`; **conditional** — absent in edit mode |
| `Gd.Notification` + `Gtk.Label` | 1 | — | — | in-window notification, 5s, closable; messages `Invalid QR code` and `zbar library is not found. QRCode scanner will be disabled` |

Provider list is loaded from the GResource `data.json` (name → logo), sorted
case-insensitively. Validation emits `changed` with the AND of name, provider
and token validity.

→ `lib/account_config.rb` — **missing**.

## Authenticator/widgets/accounts/edit.py — EditAccountWindow

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | — | `key-press-event` (Escape closes), own `updated` (`str`, `str`) | 400×600, centred on parent |
| `Gtk.HeaderBar` | 1 | — | — | title `Edit {username} - {provider}` |
| `Gtk.Button` (save) | 1 | `suggested-action` | `clicked` → `_on_save` | `Save` |
| `Gtk.Button` (close) | 1 | — | `clicked` → destroy | `Close` |
| `AccountConfig` | 1 | — | `changed` → save sensitivity | built with `edit: true` (no token entry) |

On save: emits `updated`, and when the provider changed asks
`AccountsWidget#update_provider` to move the row to another provider group.

→ `lib/edit_account_window.rb` — **missing**.

## Authenticator/widgets/settings.py — SettingsWindow: preferences

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | — | — | 600×600, title `Settings`, transient for the main window |
| `Gtk.HeaderBar` | 1 | — | — | custom title = the stack switcher |
| `Gtk.StackSwitcher` | 1 | — | — | |
| `Gtk.Stack` | 1 | `settings-main-container` | — | pages `appearance` (*Appearance*), `behaviour` (*Behaviour*), `backup` (*Backup*) |
| `Gtk.Box` (vertical) | 3 | — | — | one per page |
| `Gd.Notification` + `Gtk.Box` + `Gtk.Label` + `Gtk.Button` | 1 | — | `dismissed` → clear database; undo `clicked` → hide | 5s undo for the destructive clear; `The existing accounts will be erased in 5 seconds` / `Undo` |

Rows: *Dark theme* / `Use a dark theme, if possible` (a `SwitchSettingsBox` on
the `night-mode` key, also flipping `gtk-application-prefer-dark-theme`);
*Clear the database* / `Erase existing accounts` (a `ClickableSettingsBox`
whose confirmation is the notification above, clearing `Database`, `Keyring`,
`AccountsManager` and `AccountsWidget`); *GPG keys location* showing the
`gpg-location` setting (a `ClickableSettingsBox` opening a folder chooser).

→ `lib/settings_window.rb` — **missing** (`Adw::PreferencesWindow`/`Dialog`
with three pages is the GTK4-era shape; the undo notification becomes an
`Adw::Toast`).

## Authenticator/widgets/settings.py — SwitchSettingsBox

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (horizontal) | 1 | `settings-box` | own `changed` (`bool`) | |
| `Gtk.Switch` | 1 | — | `state-set` → writes the GSettings boolean | state read from the schema key at build |
| `Gtk.Label` (main) | 1 | `settings-box-main-label` | — | `halign START` |
| `Gtk.Label` (secondary) | 1 | `settings-box-secondary-label` | — | `halign START` |
| `Gtk.Box` (vertical) | 2 | — | — | labels, switch |

→ `lib/switch_settings_box.rb` — **missing** (an `Adw::SwitchRow` in the port).

## Authenticator/widgets/settings.py — ClickableSettingsBox

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.EventBox` | 1 | — | `button-press-event` | the whole row is the button |
| `Gtk.Box` (vertical) | 1 | `settings-box` | — | |
| `Gtk.Label` (main) | 1 | `settings-box-main-label` | — | |
| `Gtk.Label` (secondary) | 1 | `settings-box-secondary-label` | — | mutable (`secondary_lbl.set_text`) — the GPG location updates in place |

Used three times: clear-database row, GPG-location row, and every GPG key row
in the fingerprint window.

→ `lib/clickable_settings_box.rb` — **missing** (`Gtk::EventBox` does not
exist in GTK4 — `Adw::ActionRow` activatable, or a `Gtk::GestureClick`).

## Authenticator/widgets/settings.py — SettingsBoxWithEntry

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (horizontal) | 1 | `settings-box` | — | |
| `Gtk.Label` | 1 | `settings-box-main-label` | — | `halign START` |
| `Gtk.Entry` | 1 | `error` (dynamic, on invalid) | `changed` → the owner's validator | `visibility = false` when `is_password` |

Used by `PasswordWindow` (×3) and `GPGRestoreWindow` (×1).

→ `lib/settings_box_with_entry.rb` — **missing** (an `Adw::EntryRow` /
`Adw::PasswordEntryRow`).

## Authenticator/widgets/settings.py — PasswordWindow: the backup password

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | — | — | modal, 500×400, not resizable, border 36, centred on parent |
| `Gtk.HeaderBar` | 1 | — | — | title `Backup Password`, close button |
| `Gtk.Button` | 1 | `suggested-action` | `clicked` → saves the password | `Save`, insensitive until valid |
| `SettingsBoxWithEntry` | 2–3 | — | `changed` → `_validate` | `Password`, `Repeat Password`, and **conditionally** `Old Password` when one is already set |

Validation marks each entry `error`: empty password, mismatched repeat, wrong
old password. **Note: nothing in upstream constructs `PasswordWindow`** — it is
reachable only from `Settings#backup_password`, which no row exposes. Port it
for parity, and record that it is dead UI upstream.

→ `lib/password_window.rb` — **missing**.

## Authenticator/widgets/about.py.in — AboutDialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.AboutDialog` | 1 | — | — | modal; authors `Bilal Elmoussaoui`, artists `Alexandros Felekidis`, GPL-3.0, logo icon name, program name `Authenticator`, `translator-credits`, version from `@VERSION@`, comments `Two-factor authentication code generator.`, website the GitHub repo |

→ `lib/about_dialog.rb` — **missing** (`Adw::AboutDialog`; `@VERSION@` comes
from `Authenticator::Rb::VERSION`).

## Authenticator/widgets/utils.py — the file choosers

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.FileChooserNative` | 5 call sites | — | `run()` (GTK3-only, blocking) | OPEN+SAVE × JSON (`application/json`, `JSON files`) and PGP (`application/pgp-encrypted`, `Encrypted GPG files`), plus SELECT_FOLDER with hidden files for the GPG location |
| `Gtk.FileFilter` | 4 | — | — | one per mimetype |

Four shared entry points (`import_json`, `export_json`, `import_pgp_json`,
`export_pgp_json`) plus `open_directory` — one function body, five components.

→ `lib/file_choosers.rb` — **missing** (`Gtk::FileDialog` with async callbacks
in GTK4; there is no blocking `run`).

## Authenticator/widgets/backup/gnupg.py — GPGRestoreWindow

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | — | — | 400×200, title `GPG paraphrase`, centred on parent |
| `Gtk.HeaderBar` | 1 | — | — | close button, same title |
| `Gtk.Button` | 1 | `suggested-action` | `clicked` → decrypt + import | `Import` |
| `Gtk.Box` (vertical) | 1 | `settings-main-container` | — | |
| `SettingsBoxWithEntry` | 1 | — | — | `Paraphrase`, password-style |
| `Gd.Notification` + `Gtk.Box` + `Gtk.Label` | 1 | — | — | error state: `There was an error during the import of the encrypted file.` |

→ `lib/gpg_restore_window.rb` — **missing**.

## Authenticator/widgets/backup/gnupg.py — FingprintPGPWindow

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | — | own `selected` (`str`) | 600×600, title `GPG fingerprint`, centred on parent |
| `Gtk.HeaderBar` | 1 | — | — | close button, same title |
| `Gtk.Box` (vertical) | 1 | `settings-main-container` | — | |
| `Gtk.Label` | 2 | `gpg-key-lbl` | — | section headings `Public keys`, `Private keys` |
| `ClickableSettingsBox` | N | `settings-box` | `button-press-event` → emits `selected` with the fingerprint | **repeater** — one per GPG key, uid as the title and the fingerprint as the subtitle |

→ `lib/gpg_fingerprint_window.rb` — **missing**.

## Authenticator/utils.py — provider logo loading

Not a widget, but every `Gtk.Image` in the app comes through it:
`load_pixbuf_from_provider(name, size)` lowercases and dash-joins the provider
name, looks it up in the icon theme, and falls back to the app icon, scaling
with `BILINEAR` when the theme returns the wrong size. `can_use_qrscanner()`
gates the QR button on `XDG_CURRENT_DESKTOP == gnome`.

→ `lib/provider_image.rb` — **missing** (GTK4 images take `Gio::Icon`/paintables;
`GdkPixbuf` scaling should become a `Gtk::IconTheme` lookup at a given size).

---

## Supporting (non-widget) upstream files

| Upstream | → port | Kind | Present |
|---|---|---|---|
| `Authenticator/models/settings.py` + `data/…gschema.xml` | `lib/settings.rb` | settings | no |
| `Authenticator/models/account.py` | `lib/account.rb` | model | no |
| `Authenticator/models/accounts_manager.py` | `lib/accounts_manager.rb` | model | no |
| `Authenticator/models/database.py` | `lib/database.rb` | model | no |
| `Authenticator/models/keyring.py` | `lib/keyring.rb` | model | no |
| `Authenticator/models/otp.py` | `lib/otp.rb` | model | no |
| `Authenticator/models/clipboard.py` | `lib/clipboard.rb` | model | no |
| `Authenticator/models/backup.py` | `lib/backup.rb` | model | no |
| `Authenticator/models/gnupg.py` | `lib/gpg.rb` | model | no |
| `Authenticator/models/qr_reader.py` | `lib/qr_reader.rb` | model | no |
| `Authenticator/models/screenshot.py` | `lib/screenshot.rb` | model | no |
| `Authenticator/models/logger.py` | `lib/logger.rb` | model | no |
| `search-provider/authenticator-search-provider.py.in` | `lib/shell_search_provider.rb` | search provider | no |
| `data/style.css` | `data/style.css` + loader in `application.rb` | stylesheet | no |
| `data/data.json` | `data/data.json` | provider data | no |
| `data/…gresource.xml` + `data/icons/**` | `data/icons/**` loaded directly | assets | no |
| `po/` (14 languages, 58 msgids) | `po/` | i18n | no |

**GSettings keys** (all four unported): `window-position` (`ai`, `[0,0]`),
`night-mode` (`b`, false), `is-maximized` (`b`, false), `gpg-location`
(`s`, `~/.gnupg/`).

**Stylesheet classes** (12 defined): `accounts-widget`, `accounts-container`,
`accounts-list`, `account-row`, `account-row-checkbtn`, `settings-box`,
`provider-lbl`, `gpg-key-lbl`, `token-label`, `settings-box-main-label`,
`settings-box-secondary-label`, `settings-main-container`. Dead upstream:
`application-name`, `account-name`, `counter-label`. The sheet uses GTK3-only
syntax (`@theme_bg_color`, `mix()`, a `GtkImage` type selector) and must be
rewritten against Adwaita named colours.

---

## Blockers

1. **Upstream is GTK 3; the port is GTK4 + Libadwaita.** This is not a
   mechanical port. No `.ui` files means every widget tree has to be re-derived,
   and the Adwaita equivalents (`Adw::PreferencesWindow`, `Adw::ActionRow`,
   `Adw::SwitchRow`, `Adw::EntryRow`, `Adw::StatusPage`, `Adw::ToastOverlay`,
   `Adw::AboutDialog`) change the component shapes rather than just their names.
2. **`Gd.Notification` (libgd) has no Ruby binding and no GTK4 equivalent.**
   Four in-window notifications (QR errors, zbar missing, clear-database undo,
   GPG import failure) must become `Adw::Toast` on an `Adw::ToastOverlay`.
3. **`Gtk.EventBox` is removed in GTK4**, so `ClickableSettingsBox` — used in
   the settings window and once per GPG key — needs a different mechanism.
4. **`Gtk.ComboBox` with entry + `Gtk.EntryCompletion` are removed in GTK4.**
   The provider picker (the add/edit form's centrepiece, backed by ~180
   providers from `data.json`) needs a new design.
5. **`Gtk.FileChooserNative#run` is removed**; the five chooser call sites must
   become async `Gtk::FileDialog` callbacks, which changes the control flow of
   all four backup/restore actions.
6. **Window position restore is impossible in GTK4** — the `window-position`
   GSettings key and `Window#restore_state`/`save_state` have no equivalent.
   Decide whether to keep the key dormant or drop it, and record the decision.
7. **`Gtk.SearchBar#handle_event` is gone**; the window's `key-press-event`
   forwarding becomes `set_key_capture_widget`.
8. **Non-GTK dependencies not yet in the fork's dev shell**, each gating a
   component: libsecret (keyring), sqlite3 (database), a TOTP/base32 library
   (`pyotp` upstream), zbar (QR reading), `python-gnupg` (GPG backup/restore),
   and the `org.gnome.Shell.Screenshot` D-Bus interface (area screenshot for
   QR scanning). Confirm each against `flake.nix`/`gemset.nix` before porting
   the component that needs it.
9. **`AccountsManager` is a Python `Thread` emitting a signal every second.**
   The port needs `GLib::Timeout.add_seconds` on the main loop instead; a Ruby
   thread touching widgets will not be safe.
10. **`PasswordWindow` is unreachable upstream** (nothing constructs it) and
    `HeaderBar#toggle_settings_button` references a non-existent
    `self.settings_button` — upstream bugs to port deliberately or skip
    deliberately, not by accident.

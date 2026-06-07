# Changelog

## [2.19.7] - 2026-06-07

### Changed
- Phone clicker: connection status (dot + text) moved below the toolbar and centered horizontally
- Phone clicker: Retry button stays in the top-left corner of the toolbar when disconnected

---

## [2.19.6] - 2026-06-07

### Removed
- Phone clicker: Reveal, Zoom, Cards, and Timer toggle buttons removed from the clicker top bar

---

## [2.19.5] - 2026-06-07

### Changed
- Topbar: "View" and "Color" split into two separate dropdowns; View button shows the active layout icon; Color button shows a single palette swatch
- View dropdown moved after Color dropdown in topbar order
- Font dropdown button label changed from "aA" to "Font / Шрифт"
- Presentation view: timer moved to top-left, slide counter moved to top-right
- Canvas view: minimap moved to bottom-right, slide counter moved to top-right, timer now visible in canvas view when enabled
- Timer and counter boxes made smaller and visually consistent
- Slide counter restructured into two rows: slide number and bullet-point progress
- Bullet row label translates as "point" / "пункт"
- All topbar tooltip (`title`) attributes now translate with the language switcher

---

## [2.19.4] - 2026-06-07

### Added
- Text size dropdown (Small / Medium / Large) next to the Timer toggle in the topbar — persisted in localStorage; scales all card text (headings and body) proportionally

---

## [2.19.3] - 2026-06-07

### Fixed
- Removed leftover "Запис" entry from Ukrainian help text

---

## [2.19.2] - 2026-06-07

### Added
- Phone clicker page keeps the screen awake using the Wake Lock API (Chrome for Android, Safari 16.4+)

---

## [2.19.1] - 2026-06-07

### Changed
- Renamed "Stone" theme to "Day" (EN) / "День" (UK)

---

## [2.19.0] - 2026-06-07

### Removed
- Screen recording feature

---

## [2.18.0] - 2026-06-05

### Changed
- Web clicker: replaced PeerJS with manual WebRTC + Firestore signalling (no third-party cloud relay)
- Web clicker: session codes are now 6-digit numeric only (e.g. `483920`), no letters
- Web clicker: QR code encodes `?clicker=<code>` for direct auto-connect; manual entry at `?clicker` accepts digits only
- Web clicker: Firestore stores only the SDP offer/answer during handshake and is cleaned up immediately after connection

---

## [2.17.1] - 2026-06-05

### Fixed
- Web clicker: counter (slide/bullet) no longer jumps to the left when the timer is hidden — it stays right-aligned at all times
- Web clicker: pressing Present from the phone clicker now shows a "Click to enter fullscreen" overlay on the presenter's screen, working around the browser restriction that blocks `requestFullscreen()` from non-user-gesture events
- Web clicker: phone lock/unlock no longer shows an unrecoverable "Error: network" — the peer is automatically recreated and reconnects; Retry button shown only for truly unrecoverable errors
- Web clicker: presenter correctly shows disconnected status when the clicker goes silent, using a 12-second heartbeat stale timer rather than relying solely on the WebRTC close event
- Web clicker: initial connection timeout increased from 5 s to 15 s to accommodate slower WebRTC ICE negotiation

---

## [2.17.0] - 2026-06-05

### Added
- Web clicker: full rich clicker UI for `?remote=<id>` (WebRTC/PeerJS) — slide title, speaker notes, timer (total/slide), slide/bullet counter, reveal/zoom/cards/timer toggles, Present/Stop button
- Speaker notes parsing in web markdown parser: `---text---` (single-line) and `---\ntext\n---` (multi-line) blocks, matching iOS syntax
- iOS clicker: QR scan button in Clicker popup opens in-app camera scanner (VisionKit `DataScannerViewController`) to connect without leaving the app
- iOS clicker: phone icon on View screen turns green when acting as connected clicker remote
- iOS clicker: "Disconnected" status when connection drops from presenter side; tapping phone icon after disconnect opens Clicker popup for a fresh session

### Changed
- iOS clicker landscape layout: nav buttons moved to bottom-left / bottom-right corners; notes area fills the space between
- iOS clicker: returning to View screen via ← View always lands on deck view (not editor)

---

## [2.16.0] - 2026-06-05

### Added
- iOS clicker phone mode: opening `?iosremote=<id>` in a browser activates the phone remote UI (← / →) and relays commands to the iOS app via Firestore

### Changed
- Share confirmation dialog now includes a "Do not share sensitive or confidential data" warning (English and Ukrainian)

---

## [2.15.0] - 2026-06-05

### Added
- Reveal toggle to enable/disable one-by-one bullet reveal in presentation mode
- Ukrainian translations for new controls: Autoplay → Автоплей, Reveal → Сходи, Zoom → Зум

### Changed
- Autoplay always starts from the first card
- Back navigation respects the Reveal toggle (no bullet-by-bullet stepping when disabled)

---

## [2.14.0] - 2026-06-05

### Added
- Autoplay button in the topbar (after Present): picks an interval (3 s, 5 s, 10 s, 30 s, 1 min) and auto-advances slides, entering presentation mode automatically; stops at the last slide or on Esc

---

## [2.13.0] - 2026-05-25

### Added
- Ukrainian translations for template confirm modal (`tplModalTitle`, `tplModalBody`, `tplModalCancel`, `tplModalInsert`)
- Ukrainian template variants: `ukr/4-mind-map.md`, `ukr/hackaton-pitch.md`; language-specific `index.json` manifests in `eng/` and `ukr/`
- Template picker loads templates from language-specific subdirectory (`eng/` or `ukr/`) based on current UI language; reloads on language switch
- Privacy policy page at `docs/privacy.html` (covers analytics, share links, local storage)

### Changed
- Template confirm replaced browser `confirm()` with custom modal ("Insert template" / warning text / Cancel + Insert buttons)
- Nested bullet points now render as flat siblings in a single `<ul>` with `margin-left` depth indentation — eliminates CSS opacity compounding between parent and child `li` elements during reveal
- Bullet reveal transition moved to `.shown` state only: hiding is instant, revealing animates in — fixes gray flash when card first becomes active in presentation mode
- Nested `li` no longer carry their own `color` override; all bullets inherit color uniformly

---

## [2.12.0] - 2026-05-24

### Added
- Template picker in editor header: fetch and insert `.md` templates from `docs/assets/templates/`
- `index.json` manifest for templates; initial templates: Mind Map, Hackathon Pitch
- "Templates" button translates to "зразки" in Ukrainian

### Changed
- Map view: secondary H1 nodes (e.g. conclusion) now appear below the root with a vertical S-curve connector, instead of being split left/right with H2s
- Logic view: same treatment — secondary H1s stack vertically below root instead of branching right
- Hiding/showing the editor sidebar no longer triggers a camera zoom/pan

---

## [2.11.0] - 2026-05-24

### Added
- Canvas pan: drag the background to move the view (grab/grabbing cursor, pointer capture)
- Canvas zoom: scroll wheel zooms in/out keeping the point under cursor fixed
- Fit-all button redesigned as a 44px circle with expand-arrows icon, matching iOS style

### Changed
- All card content (bullets, lede) always visible in canvas view — reveal animation scoped to presentation mode only
- Visited card dimming (grey background, faded border) scoped to presentation mode only
- View mode switch (Timeline/Map/Logic) now fits all cards into view instead of zooming into the active card

---

## [2.10.0] - 2026-05-24

### Added
- Google Analytics (GA4) tracking via Measurement ID G-R1SJ19CDMP
- iOS app: share link creation from deck view (Firestore REST API, native share sheet)
- iOS app: open shared links directly in app via Universal Links and custom URL scheme (`demka://`)
- iOS app: pull-to-refresh in editor to sync content from a loaded share
- iOS app: share confirmation sheet before creating a link (matches web flow)

### Changed
- Responsive topbar: new 960px and 800px breakpoints prevent overflow at half-laptop widths
- At ≤960px: toggle labels, logo subtitle, word count meta and Clicker button hidden; buttons slimmed
- At ≤800px: Record and Help buttons hidden; Present keyboard hint hidden

---

## [2.9.0] - 2026-05-23

### Added
- Ukrainian translations for view labels (Таймлайн / Карта / Логіка) and color palette names (Камінь / Північ / Бурштин)
- Ukrainian translations for custom color field labels (Фон / Картки / Текст / Акцент) and "Custom" → "Власний"

### Changed
- Share and Export merged into a single "Share ▾" dropdown with a "Download" group header
- "Download" group header translates to "Завантажити" in Ukrainian
- "посилання" replaced with "покликання" throughout all Ukrainian share strings

---

## [2.8.0] - 2026-05-23

### Added
- Ukrainian translations for the entire share modal (all steps, buttons, bullet notes)
- Zoom toggle button in toolbar to enable/disable bullet reveal zoom
- Zoom-to-reveal now works in timeline view (was previously disabled)
- App version display in the help (?) popup

### Changed
- Share info description converted to a bullet list with future-tense wording
- Share link TTL extended from 7 days to 1 month; expiry shown in both info and done steps
- View switcher and color palette merged into a single "View" dropdown
- View mode icons replaced with stroke SVGs: → (timeline), × (map), K (logic)
- First H1 promoted as root in map/logic views when multiple H1s are present
- Bullet list dash alignment fixed using flexbox (was absolute positioning)
- Numbered list alignment fixed with `align-items: baseline`
- Minimap size reduced; padding added so dots always stay within the container

---

## [2.7.0] - 2026-05-22

### Added
- App version constant (`APP_VERSION`) and display in the UI

### Changed
- First H1 is now treated as the root node in map and logic views

---

## [2.6.0] — Timeline view redesign

### Added
- Horizontal timeline layout: spine connects card headers left-to-right
- H3 children stacked below their H2 parent on the timeline
- `drawTimelineSpine()` renders spine and branch connectors
- `fitTimeline()` fits the full timeline on screen without affecting active/visited state

### Changed
- Timeline camera uses same zoom-to-card behaviour as map/logic views
- `zoomToReveal` disabled in timeline mode to prevent zoom on bullet reveal

---

## [2.5.0] — Sharing via Firebase

### Added
- Firebase Firestore integration for sharing (replaces URL-encoded links)
- Firebase App Check with reCAPTCHA v3 to prevent abuse
- Re-sharing updates the existing Firestore document instead of creating a new one
- Share modal with loading/done/error steps
- Expiry date shown in share modal

### Changed
- Share URL format changed from `#v1:...` (base64) to `#share:<docId>`
- Images compressed to 420px before upload

---

## [2.4.0] — Language switcher & export

### Added
- Language switcher dropdown (English / Ukrainian)
- Full Ukrainian (`uk`) localisation for all UI strings
- Export to PDF, PPTX, and Markdown

---

## [2.3.0] — Phone clicker / remote

### Added
- Phone remote control via QR code (PeerJS)
- Retry button and improved connection handling for mobile browsers

---

## [2.2.0] — Timer & recording

### Added
- Presentation timer (total and per-slide) with toggle
- Screen recording with optional microphone audio
- Recording downloaded automatically as `.webm`

---

## [2.1.0] — Color palette & theming

### Added
- Built-in color palette presets
- Custom color inputs via front matter (`font_color`, `background_color`, `accent_color`)
- "Amber" palette

---

## [2.0.0] — Map & Logic views

### Added
- Map view: center H1 with H2s split left/right (mind-map style)
- Logic view: left-to-right tree with parents centred over children
- View picker dropdown
- Minimap overview

### Changed
- Fit-all overview (key `0`) with active/visited card state preserved on re-entry

---

## [1.0.0] — Initial release

### Added
- Single-file markdown-to-slides app
- Timeline view with horizontal layout
- Bullet reveal one-by-one in presentation mode
- `E` key toggles editor visibility
- Cards / no-cards toggle
- Auto-save to `localStorage`
- Help modal with keyboard shortcuts
- Favicon and Open Graph meta tags

# Changelog

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

# Theme and Language Model

v0.9.0 adds visible UI controls for theme and language in the desktop Settings screen.

Theme options:

- Light.
- Dark.
- System.

The current implementation stores the theme preference in local UI state and `localStorage` when available. It changes the app theme only and does not modify operating-system appearance.

The Settings UI uses rounded segmented controls for theme and language selection. The controls are designed to feel closer to macOS Settings than raw browser selects: calm, polished, rounded, and explicit about the active state.

Language options:

- English.
- Simplified Chinese.
- Traditional Chinese.

The current implementation provides UI-level translation for key navigation and safety labels. Existing locale files are preserved. Full i18n wiring for every string, backend output, report text, and schema validation messages remains future work.

Theme and language preferences are display settings. They must not affect installer policy, approval state, command risk, or execution permissions.

Light mode now uses an Iceland ice blue inspired gradient and a subtle CSS fluid-motion background layer. Dark mode remains graphite/blue with only consistency updates.

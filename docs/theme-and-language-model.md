# Theme and Language Model

v0.9.0 adds visible UI controls for theme and language in the desktop Settings screen.

Theme options:

- Light.
- Dark.
- System.

The current implementation stores the theme preference in local UI state and `localStorage` when available. It changes the app theme only and does not modify operating-system appearance.

Language options:

- English.
- Simplified Chinese.
- Traditional Chinese.

The current implementation provides UI-level translation for key navigation and safety labels. Existing locale files are preserved. Full i18n wiring for every string, backend output, report text, and schema validation messages remains future work.

Theme and language preferences are display settings. They must not affect installer policy, approval state, command risk, or execution permissions.

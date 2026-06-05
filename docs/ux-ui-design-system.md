# UX UI Design System

v0.9.0 introduces a premium desktop visual system for a safe local AI development setup assistant.

Design goals:

- Professional developer tool.
- Safety-first installation approval dashboard.
- Clean intelligent desktop utility.
- Premium technical product.

Design tokens:

- Primary: custom ice/racing blue.
- Secondary: deep navy.
- Light background: Iceland ice blue inspired gradient over glacier white.
- Dark background: near-black graphite.
- Accent: cyan-blue for active technical states.
- Success: safety green.
- Warning: amber.
- High risk: orange.
- Danger: red.
- Disabled: neutral gray.
- Focus ring: soft cyan glow.

Shape and layout:

- Rounded panels, buttons, cards, and icon containers.
- Soft shadows and subtle borders.
- Dashboard status cards.
- Clear risk badges and approval banners.
- Controlled information density.

Motion:

- Light mode uses a CSS-only fluid background layer with blurred frost-blue gradients and a low-opacity shimmer.
- Motion intensity must stay medium-low and must not distract from diagnostic text or approval controls.
- `prefers-reduced-motion` should reduce animation.
- Dark mode remains graphite/blue and is not heavily redesigned in v0.9.0.

Settings controls:

- Theme and language controls use macOS-style rounded segmented buttons instead of raw browser selects.
- Active, hover, pressed, and focus states must remain visible in both light and dark mode.
- Theme and language are display preferences only; they must not alter policy, approval state, or execution permissions.

Website planning:

- Future website work is deferred.
- GitHub Pages can be used later for a temporary public preview.
- Website visual direction should align with the desktop app but must not copy external reference branding or proprietary visuals.

The UI must not use Ferrari trademarks, logos, names, or copyrighted brand assets. The palette is product-safe and custom.

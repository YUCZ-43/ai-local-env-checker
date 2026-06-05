# Website Landing Page Plan

This document is planning only. v0.9.0 does not implement the website.

## Purpose

The future website should introduce AI Local Environment Checker as a safe, local-first desktop and CLI assistant for checking and preparing AI development environments. It should explain what the product does, link to GitHub, guide downloads, route users to documentation, and make the safety model clear before users run anything locally.

## Target users

- Technicians diagnosing customer machines.
- Beginner local AI users who need a safer setup path.
- AI developers preparing local tooling.
- Internal deployment operators standardizing workstations.
- Teams that need local reports before troubleshooting.

## Product positioning

The site should position the product as a professional safety-first approval dashboard, not a one-click installer. The main promise is check-first, dry-run-first, local-first environment readiness and controlled approval review.

## Page sections

- Hero: product name, one-line positioning, GitHub link, documentation link, and future download/get-started buttons.
- Safety-first overview: no silent install, no automatic UAC, no PATH/proxy/global environment mutation by default.
- Desktop approval dashboard: screenshots of Dashboard, Admin Permission Review, Command Approval, and Settings.
- Supported platforms: Windows as primary, WSL/Linux/macOS as detection previews.
- Tool coverage: Node.js, npm, Git, VS Code, WSL, local AI CLIs, proxy readiness, PATH checks.
- Documentation: quickstart, security model, install-plan model, report model, troubleshooting.
- Open-source/GitHub: repository link, issue link, contribution path, release notes.
- Downloads: future local packages and desktop builds, with checksum/signing notes when available.
- Security and privacy: local logs/reports, sanitization reminders, no upload without consent.

## Link strategy

- Primary GitHub link should point to the repository root.
- Documentation links should point to repository docs first, then a generated docs site later.
- Download buttons should stay disabled or marked future until public release artifacts are ready.
- The website should not imply that real third-party installation is enabled.

## Visual direction

Use the same desktop direction: cold off-white, ice-gray, glacier blue gradients, near-black navy text, subtle cyan light, rounded panels, and calm technical spacing. External references are design inspiration only; do not copy trademarks, logos, brand assets, or proprietary visual compositions.

## Future screenshots needed

- Light mode Dashboard.
- Dark mode Dashboard.
- Admin Permission Review.
- Command Approval with blocked command.
- Settings with theme/language segmented controls.
- Reports/logs viewer.

## Technical stack options

- Static HTML/CSS/TypeScript for the smallest preview.
- Vite static site if the repo wants shared tooling with the desktop frontend.
- Astro or Next.js only if documentation, SEO, and generated content needs justify it.

## SEO and content direction

Initial content should target plain-language searches around local AI environment check, Windows AI development setup, WSL readiness, Node.js/npm/Git diagnostics, and safe local installer approval. SEO copy must remain conservative and must not promise automatic repair.

## Deferred work

Website implementation, visual assets, screenshots, hosting setup, analytics, domain configuration, and download automation are deferred until after v0.9.0 desktop self-test review.

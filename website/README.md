# Website Preview

This directory contains the static v0.9.0-alpha.1 product website preview for AI Local Environment Checker.

## Scope

- Static HTML, CSS, and local JavaScript only.
- No analytics.
- No remote tracking.
- No remote scripts.
- No package manager dependency.
- GitHub Pages, Vercel static preview, and Cloudflare Pages friendly.

## Local preview

Open `website/index.html` directly in a browser, or serve the directory with any local static server.

For a single-file review artifact, open `preview/website-preview.html`.

## Release accuracy

The page may link to `v0.9.0-alpha.1` as an alpha prerelease target, but it must not claim that macOS or Linux installers exist until those artifacts are actually produced. Windows package wording must stay limited to this app's own alpha package artifact.

## Deployment notes

GitHub Pages is the recommended temporary public preview route. Vercel and Cloudflare Pages are suitable for preview hosting, but this alpha does not bind production domains, modify DNS records, create paid resources, or deploy production.

Suggested preview-only settings:

- GitHub Pages: publish `website/` with a manually approved Pages workflow or a dedicated preview branch.
- Vercel: set Root Directory to `website`, Framework Preset to `Other`, leave Build Command blank, and use `.` as the Output Directory.
- Cloudflare Pages: set Root Directory to `website`, use no framework preset, leave Build Command blank (or use `exit 0`), and use `.` as the Build output directory.

Do not connect a production domain or enable production deployment without owner confirmation.

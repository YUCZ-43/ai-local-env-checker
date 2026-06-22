# Website Hosting Options

This document covers hosting routes for the static `website/` preview added for v0.9.0-alpha.1. The preview can be served as static files, but this alpha does not deploy production, bind a custom domain, modify DNS, or create paid resources.

## GitHub Pages

GitHub Pages is suitable for a temporary public preview because the project already uses GitHub and can host static content directly from a branch or workflow output. It is a good first step for documentation, project overview, and screenshots.

Tradeoffs:

- Best for static pages.
- Limited server-side behavior.
- Public repo workflows and permissions must be managed carefully.

## Vercel

Vercel is suitable if the future site uses a framework such as Next.js, or if preview deployments and edge caching are useful.

Tradeoffs:

- Strong developer experience.
- External hosting dependency.
- Product download and security messaging must stay explicit.

## Cloudflare Pages

Cloudflare Pages is suitable for international static hosting, fast edge delivery, and simple static-site deployments.

Tradeoffs:

- Good for static sites and docs.
- Requires separate project configuration.
- Download artifacts should still be managed through GitHub Releases or a controlled release process later.

## Domestic domain option

A mainland China hosted site may require ICP filing if hosted on mainland infrastructure. This should be planned later after product positioning, legal ownership, domain choice, and hosting region are clear.

Tradeoffs:

- Better domestic access when properly hosted.
- ICP filing adds process time and compliance work.
- Content, download, and privacy statements need review before launch.

## Recommendation

Use GitHub Pages first for a temporary static preview. Vercel or Cloudflare Pages can be used for preview deployment after owner confirmation, with no production domain and no DNS changes. Defer domestic hosting until product ownership, ICP/compliance requirements, download policy, and public launch timing are clear.

Preview configuration:

- GitHub Pages: deploy the `website/` directory through a manually approved Pages workflow.
- Vercel: Root Directory `website`, Framework Preset `Other`, blank Build Command, Output Directory `.`.
- Cloudflare Pages: Root Directory `website`, no framework preset, blank Build Command or `exit 0`, Build output directory `.`.

These settings prepare preview hosting only. They do not authorize production deployment, custom-domain binding, DNS changes, paid resources, or analytics.

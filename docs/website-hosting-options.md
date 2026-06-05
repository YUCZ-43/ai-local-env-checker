# Website Hosting Options

This document is planning only. v0.9.0 does not deploy a website.

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

Use GitHub Pages first for a temporary static preview. Revisit Vercel or Cloudflare Pages when the landing page, docs structure, screenshots, and download strategy are ready. Defer domestic hosting until there is a clear public launch plan.

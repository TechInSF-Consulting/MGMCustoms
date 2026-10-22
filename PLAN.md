# MG&M site rebuild: plan

Goal: replace the WordPress site at mgmcustoms.com with a fast, mobile-first, **three-page** static site hosted on our Dokploy server. All the current content carries over, and every old URL redirects to its new home.

**Status (2026-10-21):** built in [site/](site/), on branch `site-rebuild`. It runs under the real Caddyfile locally, `check.sh` passes, and all 3 pages score 100 on Lighthouse a11y/BP/SEO. Not deployed yet. Forms are placeholders (§8). See [README.md](README.md) to run or deploy it.

**Decisions made:**
- Plain HTML + Caddy.
- Google Analytics kept, behind our own small consent bar; GA loads only after Accept.
- Forms are placeholder UI until a backend is chosen.
- `prototype/` is kept for reference.
- Original site images are reused to break up the text: service icons on Home, one photo per commodity on Services, two historical photos in "Who we are". Licenses and the required CC BY credits are listed in README → Images and licenses.
- Contact page map: Google Maps Embed API behind a tap-to-load preview (no Google scripts or cookies until the visitor taps). Key comes from the `GOOGLE_MAPS_EMBED_KEY` env var in Dokploy; without it, the button opens Google Maps in a new tab.
- Ted Mittelstaedt is no longer in the staff list. He still appears in the company history and timeline.
- "Who We Are" and the staff bios use the original site's wording verbatim (from the old Who We Are and Our Staff pages), arranged to tell the father-to-son story, with the family photo of Ed, his mother and Ted. The timeline is built from facts in those same pages.

## 1. Site structure

| Page | URL | What's on it |
|---|---|---|
| **Home** | `/` | Hero with call button and proof points · Services teaser · **Who we are** (story + timeline, `#about`) · **Our staff** (`#team`) · Call-to-action band |
| **Services** | `/services` | **Documents to Complete** box beside the heading: the four client forms and three numbered steps (download, fill out, send by fax or upload) (`#documents`) · Customs clearance, freight forwarding, bonds & insurance · **What we do**: the full text of the old What We Do and commodity pages (`#commodities`) · **Submit documents** and **Track a shipment**, each a half-page widget (`#clients`, with an "Already a client?" jump link at the top) |
| **Contact** | `/contact` | Phone, fax and address · Message form · "New client?" note pointing to the forms |
| *Footer, on every page* | | **Resources:** the four agency links (CBP, FDA, USDA, FWS) · Address and phone · NCBFAA terms |

- The **News** page is removed; `/news` redirects to `/`.
- The nav is **Who we are** (jumps to `/#about` on Home), **Services** and **Contact**, with the logo linking Home. There is no menu button; on phones the three links sit in their own row under the logo.
- Phones also get a sticky Call/Message bar at the bottom of the screen.

## 2. Where the current site stands (audited 2026-10-21)

It runs WordPress 7.1.3 on Flywheel, with the "Mammoth" theme (2014), Visual Composer, Gravity Forms, CleanTalk, CookieYes and Google Site Kit.

| | Live homepage | Prototype homepage |
|---|---|---|
| Requests | 58 | 3 (HTML, CSS, font) |
| Transfer size | ~205 KB | ~42 KB (3.5 KB HTML + 3 KB CSS gzipped, 35 KB font) |
| Scripts | 23 (jQuery, Chart.js, audio player, emoji…) | 0 (Services and Contact have one small inline form script) |
| Third-party hosts | 7 | 0 |
| First paint / LCP, Slow 4G + 4× CPU (cold loads, typical) | 3.6–5.3 s | 1.9–2.5 s |
| CLS | 0.04 | 0 |
| Lighthouse Accessibility / Best Practices / SEO (mobile) | 88 / 92 / 85 | 100 / 100 / 100 on all 3 pages |

The load times are lab numbers from a laptop and vary a lot between runs: both sites occasionally produced much slower outliers. Phase 4 re-measures on the staging URL with PageSpeed Insights, which is the number to report to MG&M.

Problems on the live site that the rebuild fixes:
- **"Submit Documents" is broken.** It links to `dropbox.yousendit.com`, a service that shut down years ago.
- The mobile menu is a native `<select>` dropdown that has no label.
- The cookie banner covers half the first screen on a phone.
- There is no phone number anywhere on the homepage.
- Text and link colors fail WCAG contrast: body text is 3.5:1 and links are 2.1:1.
- Chart.js, an audio player and emoji scripts load on every page, but nothing uses them.

## 3. Targets (per page, on mobile)

- HTML under 15 KB gzipped, CSS under 5 KB, total first load under 60 KB including the font.
- JS: zero, except the form handler on the two pages that have forms (under 2 KB).
- LCP under 1.8 s on PageSpeed Insights mobile; CLS 0; Lighthouse a11y/SEO/BP at 100.
- Phone number one tap away on every page.

## 4. Stack: plain HTML served by Caddy, no build step

With three pages, a static-site generator isn't worth it.

- **Shared parts:** Caddy's built-in `templates` feature includes the shared header, footer and call bar into each page when it's served, so they live in one file each. There's no Node, no `npm install`, and no build that can break.
- **Current-page highlight in the nav** is set in the header template: `{{if eq .OriginalReq.URL.Path "/services"}} aria-current="page"{{end}}`.
- **Content** is edited directly in the three HTML files. If MG&M staff need to edit text themselves, see open question 1.
- **Font:** Archivo, self-hosted, latin subset, weight axis only (35 KB), with `font-display: optional`. Everything else uses the system font stack.
- **Staff photos** (4 of them): pulled from the live site, cropped and converted to 216 px WebP files of 5–10 KB, lazy-loaded with explicit `width`/`height`.
- **sitemap.xml** is written by hand; it's three URLs.
- **One script, `site.js`** (~2 KB, deferred), handles the consent bar, GA loading and the form placeholders. Nothing is inline, so the CSP needs no `'unsafe-inline'`.

```
site/
  index.html  services.html  contact.html  404.html
  site.css  site.js  favicon.png  sitemap.xml  robots.txt
  _partials/head.html  header.html  footer.html (footer + call bar + consent bar)
  fonts/archivo-latin.woff2
  img/staff/*.webp
  wp-content/uploads/2014/05/*   ← the four forms, at their old paths
```

### Replacing the WordPress plugins

| Today | Replacement |
|---|---|
| Visual Composer, Mammoth theme, jQuery | Gone (`site.css` is 3 KB gzipped) |
| Gravity Forms (contact) | **Placeholder for now.** The form validates input, then asks the visitor to call. Backend to be chosen (question 3). |
| *(new)* Submit-documents widget | **Placeholder for now.** The UI is built, with no upload destination yet (question 2). |
| CleanTalk anti-spam | Honeypot field is in both forms; it gets enforced once a backend exists. |
| Google Site Kit / GA | **Kept:** the same Google tag (`GT-WF6WRVH5`), loaded directly by `site.js`. The dead Universal Analytics ID (`UA-51407227-1`) is dropped. |
| CookieYes banner | **Replaced** by our own compact consent bar (~1 KB). GA's ~150 KB script loads only after Accept, so visitors who decline or ignore the bar never download it. "Cookie settings" in the footer reopens the bar; Decline also deletes `_ga` cookies. |
| wp-charts, audio.js, emoji | Removed |
| gtrac tracking link | Kept, as the Track widget's button, switched to `https://` |

## 5. Redirects (old URL → new)

| Old | New |
|---|---|
| `/who-we-are` | `/#about` |
| `/our-staff` | `/#team` |
| `/who-we-are/what-we-do` | `/services#commodities` |
| `/customs-clearance` | `/services#customs-clearance` |
| `/freight-forwarding` | `/services#freight-forwarding` |
| `/bonds-and-insurance` | `/services#bonds-and-insurance` |
| `/commodities/<slug>` (8 pages) | `/services#<slug>` (the prototype already uses those slugs as IDs) |
| `/resources` | `/services#documents` |
| `/contact-us` | `/contact` |
| `/news`, `/news/*` | `/` |
| `/feed`, `/wp-login.php`, `/wp-admin/*`, `/xmlrpc.php` | `410 Gone` |

- Trailing slashes are stripped first, so `/our-staff/` works as well as `/our-staff`.
- The four form downloads stay at their exact `/wp-content/uploads/2014/05/...` paths, so links in old emails keep working.
- Each page keeps a `<title>` and meta description based on the current ones.
- Home carries the `ProfessionalService` JSON-LD (address, phone, founding year).

## 6. Dokploy deployment

Dokploy builds from this repo with a Dockerfile. Its Traefik proxy handles the domain and the Let's Encrypt certificate, so the container serves plain HTTP on port 80.

The real config is in [Dockerfile](Dockerfile) and [Caddyfile](Caddyfile). It has been validated and run locally with Caddy 2.11.7, and `check.sh` covers every redirect in §5. Beyond the original plan, it also:

- redirects `www` to the apex domain
- redirects `/services.html` → `/services`
- returns 404 for `/_partials/*`
- allows the Google Analytics domains in the CSP
- takes `PORT` and `SITE_ROOT` env overrides for local runs

The `:{$PORT:80}` site address keeps Caddy on plain HTTP, so it doesn't clash with Traefik.

Dokploy setup:
- A **staging** app on `new.mgmcustoms.com`, deploying from `main`.
- **Production** uses the same image. Point `mgmcustoms.com` and `www` (redirecting to the apex) at it during cutover.
- Turn on auto-deploy from the git webhook. The Dockerfile already has a `HEALTHCHECK` on `GET /`.

## 7. Phases

**Phase 0: decisions.** ✅ Stack, analytics/consent and repo layout are decided. Still open: the questions below, plus the logo vector files.

**Phase 1: content** ✅
- The full text of the old What We Do page and all 8 commodity pages is on /services (two grammar fixes: "identified upon" → "identified"; "insure" → "ensure"), and the old URLs redirect to its anchors.
- The 4 form files and the staff photos are in `site/`.
- Keep a full WP export and a Flywheel backup as the archive.

**Phase 2: build** ✅
- `site/` is built from the prototype, with the header, footer, call bar and consent bar in `_partials/`.
- The Caddyfile and Dockerfile validate and run under Caddy 2.11.7, and `check.sh` passes.

**Phase 3: integrations.** Open: connect the contact form and the document upload, and add a restricted Google Maps Embed key. Done: GA with consent, and the Track link on https.

**Phase 4: quality checks**
- PageSpeed Insights and Lighthouse on staging against §3.
- Every old URL in §5 returns its redirect.
- Real-device check on an iPhone and a mid-range Android.
- Keyboard and screen-reader pass on the nav, both forms and the file input.

**Phase 5: cutover**
1. Lower the DNS TTL to 300 a day ahead.
2. Switch the A/AAAA records to the Dokploy server.
3. Resubmit the sitemap in Search Console.
4. **Keep Flywheel running for 30 days** as the rollback, which just means pointing DNS back.

## 8. Open questions for MG&M

1. **Who edits the site, and how often?** If it's "rarely, through us", plain HTML is enough. If staff need to edit it themselves, we'd add a small git-based CMS, which brings back a build step.
2. **Where should uploaded documents go?** These are POAs, invoices and credit apps, so they need a secure destination, not a plain email attachment. If their brokerage software has a client portal or a secure intake inbox, we send uploads there. Otherwise we pick a secure upload service together.
3. **Which inbox** should contact-form messages go to? And which email address should step 3 of the "Documents to Complete" box list? The original said "send to us by fax or email" but never showed an address (staff emails were hidden by CleanTalk). For now it says fax or upload.
4. ~~Does anyone use the GA data?~~ Decided: keep GA, behind our own consent bar.
5. **Logo and photos:** do they have vector logo files (SVG/AI/EPS) and the originals of the staff photos?
6. ~~Does gtrac work over https?~~ Yes: verified 200 with a valid cert.
7. The staff page shows 4 people, but they say they have 10 employees. Should the team section include anyone else?

## 9. What stays out (until someone asks)

Dark mode, animations, an embedded Google Map (500 KB+; we link to Maps instead), and a News or blog section. (The Home header photo, the Golden Gate with a container ship, was added at 9–58 KB per size depending on screen.)

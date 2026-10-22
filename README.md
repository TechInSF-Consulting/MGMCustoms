# MG&M Customs website

The website for **Mittelstaedt, Galaviz & Mylin, Inc.** (mgmcustoms.com), a San Francisco customs broker and freight forwarder.

It replaces the old WordPress site on Flywheel with three hand-written HTML pages served by [Caddy](https://caddyserver.com) in a Docker container, hosted on **[Dokploy](https://dokploy.com)**. There is no framework, no build step, no database and no Node at runtime.

- **Live (after cutover):** https://mgmcustoms.com
- **Plan, audit and open decisions:** [PLAN.md](PLAN.md)

---

## Contents

- [How it works](#how-it-works)
- [Repository layout](#repository-layout)
- [Pages and URLs](#pages-and-urls)
- [Run it locally](#run-it-locally)
- [Hosting on Dokploy](#hosting-on-dokploy)
- [Editing the site](#editing-the-site)
- [Images and licenses](#images-and-licenses)
- [Analytics and cookie consent](#analytics-and-cookie-consent)
- [Contact map (Google Maps Embed API)](#contact-map-google-maps-embed-api)
- [Forms (placeholders)](#forms-placeholders)
- [Redirects](#redirects)
- [Security headers](#security-headers)
- [Performance budget](#performance-budget)
- [Troubleshooting](#troubleshooting)
- [Before launch](#before-launch)

---

## How it works

```
visitor ──HTTPS──▶ Dokploy (Traefik: TLS, Let's Encrypt) ──HTTP :80──▶ Caddy container ──▶ site/
```

- **Traefik** is Dokploy's built-in proxy. It owns the domain, the TLS certificate and the HTTP→HTTPS redirect.
- **Caddy** serves the files in `site/` on plain HTTP port 80. It also:
  - inserts the shared header and footer into each page (its `templates` feature)
  - compresses responses
  - handles every redirect from the old WordPress URLs
  - sets cache and security headers
- **Pages are plain HTML.** The header, footer and `<head>` boilerplate live once in `site/_partials/` and are included with `{{include "/_partials/header.html"}}`.
- **JavaScript** is one ~2 KB file (`site.js`) that runs the cookie-consent bar, loads Google Analytics after consent, and handles the form placeholders. Pages work without it.

## Repository layout

```
.
├── site/                      Everything that gets served (copied to /srv in the image)
│   ├── index.html             Home: hero, services teaser, who we are, staff
│   ├── services.html          Services, What we do (commodities), client widgets
│   ├── contact.html           Phone, address, message form
│   ├── 404.html               Not-found page (also rendered through templates)
│   ├── _partials/
│   │   ├── head.html          Shared <head>: charset, viewport, favicon, font preload, CSS, JS
│   │   ├── header.html        Logo + nav (marks the current page)
│   │   └── footer.html        Footer with resources, phone call bar, cookie-consent bar
│   ├── site.css               All styles (~3 KB gzipped)
│   ├── site.js                Consent + GA loader + form placeholders
│   ├── fonts/                 Archivo variable font, latin subset (35 KB)
│   ├── img/                   logo, Home header photo, icons/, commod/, history/, staff/  (see "Images and licenses")
│   ├── wp-content/uploads/2014/05/   The four client forms, kept at their old URLs
│   ├── favicon.png  robots.txt  sitemap.xml
├── Caddyfile                  Server config: redirects, headers, caching, templates
├── Dockerfile                 caddy:2.11.7-alpine + Caddyfile + site/
├── .dockerignore              Only Caddyfile and site/ go into the build context
├── check.sh                   Smoke test: pages, every redirect, headers
├── PLAN.md                    Rebuild plan, audit numbers, decisions, open questions
└── prototype/                 Original design prototype (reference only, not deployed)
```

## Pages and URLs

| URL | File | Sections (anchor IDs) |
|---|---|---|
| `/` | `index.html` | Header image · hero · services teaser · Who we are (`#about`, linked from the nav) · Our staff (`#team`) |
| `/services` | `services.html` | "Documents to Complete" box with the four forms and how to send them (`#documents`) · `#customs-clearance` · `#freight-forwarding` · `#bonds-and-insurance` · What we do: full commodity text (`#commodities`, one anchor per commodity) · Submit documents + Track a shipment (`#clients`, linked from the top of the page) |
| `/contact` | `contact.html` | Phone, fax and address · message form (`#message`) · map (tap to load) |
| *(every page)* | `_partials/footer.html` | **Resources** (`#resources`): Government agencies |

URLs are clean: `/services.html` redirects to `/services`, and trailing slashes are stripped.

## Run it locally

You need **Caddy 2.11+**: [download it](https://caddyserver.com/download), or use `brew install caddy`, `choco install caddy` or `scoop install caddy`. Docker isn't required for local work.

```sh
# from the repo root
SITE_ROOT=./site PORT=8780 caddy run --config Caddyfile
# open http://localhost:8780

# in a second terminal
sh check.sh                       # defaults to http://localhost:8780
```

On Windows PowerShell:

```powershell
$env:SITE_ROOT="./site"; $env:PORT="8780"; caddy run --config Caddyfile
```

> **Always view pages through Caddy.** If you open `site/index.html` directly as a file, you'll see raw `{{include ...}}` tags instead of the header and footer.

`SITE_ROOT` and `PORT` only exist for local runs. In the container they default to `/srv` and `80`.

To run the production container instead (if you have Docker):

```sh
docker build -t mgm-site .
docker run --rm -p 8780:80 mgm-site
sh check.sh
```

## Hosting on Dokploy

The site deploys as a single Dokploy **Application** built from this repo's `Dockerfile`. It needs no volumes or database. The only environment variable is the optional `GOOGLE_MAPS_EMBED_KEY` for the Contact map (see [Contact map](#contact-map-google-maps-embed-api)).

### First-time setup

1. **Create the application**
   - In Dokploy, open (or create) a project, for example `MGM Customs`, then choose **Create Service → Application**.
   - Give it a name, such as `mgm-site`.

2. **Connect the source** (General tab)
   - **Provider:** GitHub (or Git, with the repo URL and a deploy key).
   - **Repository:** this repo. **Branch:** `main`. The rebuild currently lives on `site-rebuild`, so merge it first or point staging at that branch.

3. **Set the build**
   - **Build Type:** `Dockerfile`
   - **Dockerfile Path:** `Dockerfile`
   - **Docker Context Path:** `.`
   - **Docker Build Stage:** leave empty

4. **Add the domains** (Domains tab)

   | Host | Path | Container Port | HTTPS | Certificate |
   |---|---|---|---|---|
   | `mgmcustoms.com` | `/` | `80` | On | `letsencrypt` |
   | `www.mgmcustoms.com` | `/` | `80` | On | `letsencrypt` |

   Caddy already redirects `www` to the apex domain, so **don't** also turn on Dokploy's www→non-www redirect preset.

5. **Point DNS at the Dokploy server** (at the domain registrar or DNS host)
   - `A` record: `mgmcustoms.com` → the Dokploy server's public IP (plus an `AAAA` record if it has IPv6)
   - `CNAME` record: `www` → `mgmcustoms.com`

   Let's Encrypt can only issue the certificate after DNS resolves to the server.

6. **Deploy.** Click **Deploy** and watch the build log. The image builds in seconds because there's nothing to compile.

7. **Verify:**
   ```sh
   sh check.sh https://mgmcustoms.com
   ```
   It should print `all checks passed`.

### Staging

Before cutover, create a second Application (`mgm-site-staging`) with the same settings, on a staging host such as `new.mgmcustoms.com` (an `A` record to the same server). For a quick look you can use Dokploy's generated `*.traefik.me` domain instead, but that's HTTP only. Run `sh check.sh https://new.mgmcustoms.com` against it.

### Auto deploy

- **GitHub provider:** Dokploy redeploys automatically on every push to the configured branch.
- **Other Git providers:** turn on **Auto Deploy** in the General tab, copy the **Webhook URL** (shown in the Deployments tab), and add it as a push webhook in the repository settings. The pushed branch must match the branch set in Dokploy, or the deploy fails with "Branch Not Match".

### Health check, logs and rollback

- **Health check:** the image has a Docker `HEALTHCHECK` that requests `GET /` every 30 seconds.
- **Logs:** Caddy writes access logs to stdout, so they appear in the application's **Logs** tab.
- **Rollback:** redeploy a previous deployment from the **Deployments** tab, or revert the commit and push.

### Cutover from Flywheel (one time)

1. A day ahead, lower the DNS TTL on `mgmcustoms.com` to 300 seconds.
2. Confirm staging passes `check.sh` and looks right on a real phone.
3. Switch the `A`/`CNAME` records to the Dokploy server, then wait for the Let's Encrypt certificate to issue.
4. Run `sh check.sh https://mgmcustoms.com`, and resubmit `sitemap.xml` in Google Search Console.
5. **Keep the Flywheel site running for 30 days.** Rolling back just means pointing DNS back to it.

## Editing the site

| To change… | Edit |
|---|---|
| Page text | `site/index.html`, `site/services.html` or `site/contact.html` |
| Nav (Who we are · Services · Contact), logo, header phone number | `site/_partials/header.html` |
| Footer: agency links, call bar, consent text | `site/_partials/footer.html` |
| "Documents to Complete" box (the four client forms and the steps) | `site/services.html`, at the top |
| `<head>` items shared by every page | `site/_partials/head.html` |
| Page title, description, canonical | The `<head>` of that page |
| Styles | `site/site.css` |
| Scripts | `site/site.js` |

Commit and push; Dokploy redeploys. Then:

- **After changing `site.css` or `site.js`**, bump the `?v=` number on both links in `site/_partials/head.html`. Browsers cache those files for a day, so without the bump visitors keep the old version.
- **Template syntax:** anything inside `{{ }}` in an HTML file is treated as template code. To show literal braces on a page, write `{{"{{"}}`.

**Replacing the Home header image:** export the new photo (3:2 landscape works best; wide screens crop it to the middle band), then regenerate the four sizes, keeping the same filenames:

```sh
for w in 640 960 1440 2048; do npx sharp-cli -i photo.jpg -o site/img/hero-$w.webp -f webp -q 72 resize $w; done
```

Update the `alt` text on the `<img class="hero-img">` in `index.html`. To change which part of the photo stays visible on wide screens, adjust `object-position` on `.hero-img` in `site.css`.

**Text over the header image.** The headline sits on the photo. A dark gradient (`.hero::before` in `site.css`) sits behind the text: on phones the photo fades into navy under the text, on tablets and desktops it darkens from the left. Measured against the brightest pixel behind each line, every line clears WCAG AA with room to spare: at least 8.3:1 at phone, iPad (834 px), 1024 px and 1440 px widths (AA needs 4.5:1, or 3:1 for the large headline). Lighthouse can't check text over images, so **if you swap in a brighter photo, re-check on real devices** and darken the gradient stops if anything gets hard to read.

**Replacing a staff photo:** export a square crop centered on the face, then convert it to a 216 px WebP and save it into `site/img/staff/`:

```sh
npx sharp-cli -i photo.jpg -o site/img/staff/name.webp -f webp -q 78 resize 216 216 --fit cover
```

Keep the `width="72" height="72" loading="lazy"` attributes on the `<img>`.

**Replacing a client form** (POA, bond questionnaire, credit application, T&Cs): overwrite the file in `site/wp-content/uploads/2014/05/` and keep the same filename, so old links keep working. If the filename has to change, update the "Documents to Complete" box in `services.html` and `check.sh`.

**Adding a page** (the site is deliberately three pages, so check with the team first):
1. Copy `contact.html` as a starting point and keep the three `{{include}}` lines.
2. Add the page to the nav in `_partials/header.html`, using the same `aria-current` pattern.
3. Add it to `sitemap.xml` and to `check.sh`.

## Images and licenses

All images come from the original site (or MG&M), re-exported as WebP. None currently need an on-page credit; if you add a Creative Commons photo, put its credit (title, author, license link) right under it. Photos ship in two sizes (`-480` plus a larger one) and the browser picks one via `srcset`.

| Folder | What | Source and license |
|---|---|---|
| `img/hero-*.webp` | Golden Gate and CMA CGM ship (Home header) | MG&M's own photo |
| `img/icons/` | Service icons on Home (checklist, truck, container) | Original site |
| `img/history/` | First-anniversary dinner; 214 Front St. after the 1989 earthquake | MG&M's own photos |
| `img/staff/` | Ed, Jasmin, Ellie | MG&M's own photos |
| `img/commod/` | One photo per commodity | Depositphotos stock that MG&M licensed for their site. Fine to keep using on mgmcustoms.com; don't reuse them for other clients or projects. |

Adding a photo: export a 3:2 crop, then make two sizes:

```sh
npx sharp-cli -i photo.jpg -o site/img/commod/name-480.webp -f webp -q 70 resize 480 320 --fit cover
npx sharp-cli -i photo.jpg -o site/img/commod/name-800.webp -f webp -q 70 resize 800 533 --fit cover
```

Give it a real `alt` description, `width`/`height`, and `loading="lazy"` unless it's in the first screen. `check.sh` fails if a page references an image that doesn't exist.

## Analytics and cookie consent

- **Tag:** Google tag `GT-WF6WRVH5` (the same property as the old site), defined at the top of `site/site.js`.
- **Nothing from Google loads until the visitor taps Accept** on the consent bar. The choice is stored in `localStorage` under `mgm-consent`.
- **Cookie settings** in the footer reopens the bar. **Decline** turns analytics consent off and deletes `_ga*` cookies.
- To test the banner again, clear site data or run `localStorage.removeItem('mgm-consent')` in the console.
- **Adding another third-party script** means updating the CSP in the `Caddyfile` too (see [Security headers](#security-headers)).

## Contact map (Google Maps Embed API)

The Contact page shows a lightweight preview card (pin, address, **Show map**, **Get directions**). Nothing loads from Google until the visitor taps **Show map**; then `site.js` swaps in the Google Maps Embed iframe. This keeps the page fast and avoids Google cookies for visitors who never open the map.

The API key is **not in the code**. Caddy inserts it into the page from the `GOOGLE_MAPS_EMBED_KEY` environment variable (`{{env "GOOGLE_MAPS_EMBED_KEY"}}` in `contact.html`). Until it's set, **Show map** opens Google Maps in a new tab instead, so nothing breaks.

**Getting a key (one time, in MG&M's Google account):**

1. In [Google Cloud Console](https://console.cloud.google.com/), create or pick a project and enable **Maps Embed API**. Embed API usage has no charge, but Google may still ask for a billing account on the project.
2. Create an API key under **APIs & Services → Credentials**.
3. **Restrict the key.** The key is visible in the page source, as it is for every Maps embed, so the restrictions are what protect it:
   - **Application restrictions → Websites:** add `https://mgmcustoms.com/*`, `https://www.mgmcustoms.com/*` and your staging domain.
   - **API restrictions:** select only **Maps Embed API**.
4. In Dokploy, go to the application's **Environment** tab, add `GOOGLE_MAPS_EMBED_KEY=<the key>`, and redeploy.

To try it locally: `GOOGLE_MAPS_EMBED_KEY=<key> SITE_ROOT=./site PORT=8780 caddy run --config Caddyfile`.

## Forms (placeholders)

The **contact form** (`/contact`) and the **Submit documents** upload (`/services`) are **UI only for now**. They validate the fields and then tell the visitor: *"Online submission isn't connected yet. Please call (415) 362-8435."*

To wire them up once MG&M picks a backend (PLAN.md §8, questions 2–3):

1. Replace the placeholder block at the bottom of `site/site.js` with a real `fetch` POST to the endpoint.
2. Add the endpoint's origin to `connect-src` and `form-action` in the `Caddyfile` CSP.
3. Server-side, reject submissions where the hidden `website` honeypot field is filled.
4. The document upload carries powers of attorney and credit applications, so it needs a **secure** destination. Don't send those files to an arbitrary third-party form service.

## Redirects

Every old WordPress URL redirects to its new location. The map is in the `Caddyfile` under `# Old WordPress URLs`, with the reasoning in PLAN.md §5. Examples:

| Old | New |
|---|---|
| `/our-staff` | `/#team` |
| `/customs-clearance` | `/services#customs-clearance` |
| `/commodities/cheese` | `/services#cheese` |
| `/contact-us` | `/contact` |
| `/news`, `/news/*` | `/` |
| `/wp-login.php`, `/feed`, … | `410 Gone` |

When you add or change a redirect, add a matching line to `check.sh`.

## Security headers

The `Caddyfile` sets HSTS, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy` and a strict **Content-Security-Policy**:

- **Scripts** may come only from this site and Google Tag Manager; inline scripts are blocked.
- **Connections and images** are allowed only to this site and Google Analytics.
- **Frames** are allowed only from `https://www.google.com`, for the Contact map embed.
- **Styles and fonts** are allowed only from this site.
- **Embedding:** the site can't be put inside a frame on another site.

If something new is blocked (a form endpoint, a map embed, a chat widget), the browser console shows a CSP error naming the directive to extend.

## Performance budget

| Target (mobile) | Current |
|---|---|
| HTML < 15 KB gzipped | ~2–4 KB |
| CSS < 5 KB gzipped | ~3 KB |
| JS < 2 KB, deferred | ~2 KB |
| Total first load < 60 KB | ~45 KB (most of it the font) |
| Lighthouse a11y / best practices / SEO | 100 / 100 / 100 on all pages |

After deploying, measure real numbers with [PageSpeed Insights](https://pagespeed.web.dev/) on the live URL. Lab numbers from a laptop vary a lot.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Page shows `{{include "/_partials/header.html"}}` as text | You opened the file directly. Go through Caddy (`http://localhost:8780`). |
| CSS or JS change isn't showing | Bump `?v=` in `_partials/head.html`, or hard-refresh. |
| A page shows "Something went wrong on our end…" (HTTP 500) after an edit | Template error, usually a stray `{{` in the page or a partial you just edited. The Dokploy **Logs** tab shows which URL returned 500. Reproduce locally with `caddy run` and fix or escape the braces. |
| HTTPS certificate not issuing | DNS doesn't point at the Dokploy server yet. Check with `nslookup mgmcustoms.com`. |
| Dokploy deploy says "Branch Not Match" | The webhook's branch differs from the branch set in the General tab. |
| GA shows no data | Expected for visitors who declined. Accept on the bar yourself and watch GA Realtime. |
| Something is blocked in the browser console (CSP) | Add its origin to the right directive in the `Caddyfile`, then redeploy. |

## Before launch

- [ ] **Wire up the forms** (contact + document upload). See [Forms](#forms-placeholders).
- [ ] **Add the Google Maps key**: create a restricted Maps Embed API key and set `GOOGLE_MAPS_EMBED_KEY` in Dokploy. See [Contact map](#contact-map-google-maps-embed-api).
- [x] **Logo**: the real logo (`logo-mittlestaedt-011.png`, 350×85) is used in the header and favicon. A vector (SVG) version from MG&M would still be sharper on high-res screens.
- [ ] **Answer the open questions in PLAN.md §8** with MG&M: who edits the site, the upload destination, the contact inbox, and the staff list.
- [ ] **Run `check.sh` against staging** and check on a real iPhone and Android.
- [ ] **Do the DNS cutover** and keep Flywheel running for 30 days.

#!/bin/sh
# Smoke test: pages, redirects, headers. Usage: ./check.sh [base-url]  (default http://localhost:8780)
BASE=${1:-http://localhost:8780}
fail=0

check() { # path, expected status, expected Location (optional)
  out=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' "$BASE$1")
  code=${out%% *}; loc=${out#* }
  want_loc=${3:+$BASE$3}
  if [ "$code" != "$2" ] || { [ -n "$3" ] && [ "$loc" != "$want_loc" ]; }; then
    echo "FAIL $1 -> $code $loc (want $2 $want_loc)"; fail=1
  fi
}

check /                 200
check /services         200
check /contact          200
check /site.css         200
check /site.js          200
check /fonts/archivo-latin.woff2 200
check /img/staff/ed.webp 200
check /img/logo.webp    200
check /img/hero-640.webp 200
check /img/hero-2048.webp 200
check /img/icons/customs.webp 200
check /img/commod/cattle-800.webp 200
check /img/history/earthquake-1989-892.webp 200
check /favicon.png     200
check /wp-content/uploads/2014/05/powerofattorney.doc 200
check /wp-content/uploads/2014/05/bondquest.doc 200
check /wp-content/uploads/2014/05/MGM-Credit-Application.xls 200
check /wp-content/uploads/2014/05/MGM-Terms-and-Conditions-of-Service.pdf 200
check /sitemap.xml      200
check /robots.txt       200
check /nope             404
check /_partials/header.html 404

check /services/        308 /services
check /services.html    308 /services
check /index.html       308 /
check /who-we-are       301 "/#about"
check /who-we-are/      308 /who-we-are
check /our-staff        301 "/#team"
check /who-we-are/what-we-do 301 "/services#commodities"
check /customs-clearance 301 "/services#customs-clearance"
check /freight-forwarding 301 "/services#freight-forwarding"
check /bonds-and-insurance 301 "/services#bonds-and-insurance"
check /commodities/cheese 301 "/services#cheese"
check /commodities/usda-food-safety-inspection-service 301 "/services#usda-food-safety-inspection-service"
check /resources        301 "/services#documents"
check /contact-us       301 /contact
check /news             301 /
check /news/some-post   301 /
check /wp-login.php     410
check /feed             410

# Templates rendered (no raw {{ }}), nav marks the current page, security headers present
page=$(curl -s "$BASE/services")
for p in / /services /contact /nope; do curl -s "$BASE$p" | grep -q '{{' && { echo "FAIL $p has unrendered template tags"; fail=1; }; done
curl -s "$BASE/contact" | grep -q 'data-map data-key=' || { echo "FAIL /contact map preview missing"; fail=1; }
curl -sI "$BASE/contact" | grep -qi 'frame-src https://www.google.com' || { echo "FAIL CSP must allow the Google Maps embed frame"; fail=1; }
echo "$page" | grep -q 'href="/services" aria-current="page"' || { echo "FAIL /services nav not marked current"; fail=1; }
curl -s "$BASE/contact" | grep -q 'href="/#about">Who We Are' || { echo "FAIL nav missing Who We Are"; fail=1; }
curl -s "$BASE/contact" | grep -q 'href="#message"' || { echo "FAIL /contact call bar should link #message"; fail=1; }
curl -sI "$BASE/" | grep -qi '^content-security-policy:' || { echo "FAIL missing CSP header"; fail=1; }
curl -s -D - -o /dev/null -H 'Accept-Encoding: gzip' "$BASE/" | grep -qi '^content-encoding: gzip' || { echo "FAIL HTML not compressed"; fail=1; }

home=$(curl -s "$BASE/")
echo "$home" | grep -q '<h3>Ted Mittelstaedt</h3>' && { echo "FAIL Ted should not be in the staff list"; fail=1; }
echo "$home" | grep -A12 'id="resources"' | grep -q 'uploads/2014/05/bondquest' && { echo "FAIL footer should not list the forms"; fail=1; }
for f in bondquest.doc powerofattorney.doc MGM-Credit-Application.xls MGM-Terms-and-Conditions-of-Service.pdf; do echo "$page" | grep -q "uploads/2014/05/$f" || { echo "FAIL /services Documents box missing $f"; fail=1; }; done
# Every image the pages reference must exist
imgs=$( { echo "$home"; echo "$page"; } | grep -oE '/img/[^" ,]+\.webp' | sort -u)
[ -n "$imgs" ] || { echo "FAIL found no images to check"; fail=1; }
for src in $imgs; do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE$src")" = 200 ] || { echo "FAIL missing image $src"; fail=1; }
done
echo "checked $(echo "$imgs" | wc -l | tr -d ' ') referenced images"
# Every anchor the old URLs redirect to must exist; services come before the client widgets
for id in documents customs-clearance freight-forwarding bonds-and-insurance commodities clients general-cargo stone-slabs-and-tiles cheese textiles lumber fish-and-wildlife fda-ams-perishable-fruits-and-vegetables usda-food-safety-inspection-service; do
  echo "$page" | grep -q "id=\"$id\"" || { echo "FAIL /services missing #$id"; fail=1; }
done
svc_line=$(echo "$page" | grep -n 'id="customs-clearance"' | cut -d: -f1)
cli_line=$(echo "$page" | grep -n 'id="clients"' | cut -d: -f1)
[ "${svc_line:-0}" -lt "${cli_line:-0}" ] || { echo "FAIL /services: services should come before the client widgets"; fail=1; }

[ $fail = 0 ] && echo "all checks passed" || exit 1

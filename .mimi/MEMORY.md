## Website — nav alignment fix — 2026-06-03T18:45:47Z
**Summary:** Fixed docs page nav misalignment. Root cause: docs/index.html had unscoped `li { margin-bottom: 8px }` and `a { text-underline-offset: 3px }` element selectors that leaked into .nav-links li, inflating nav height and shifting text downward. Fix: scoped ALL broad element selectors in docs/index.html local <style> to .content (e.g. .content li, .content a, .content p, etc.). Also expanded sidebar-nav a transition from `all 0.15s` to explicit properties.
**Files:** docs/index.html, index.html, style.css
**Tags:** css, nav, specificity, scoping, docs

## Website — policy pages + footer — 2026-06-03T20:48:41Z
**Summary:** Created policies/ folder with privacy.html, terms.html, disclaimer.html. Moved footer CSS from index.html local style to style.css (with margin: 0 auto added). Added .footer-nav CSS to style.css. Updated index.html footer with policy links. Added footer to docs/index.html. All 3 policy pages share the same layout/nav/burger/footer pattern and have full meta+OG+JSON-LD heads.
**Files:** policies/privacy.html, policies/terms.html, policies/disclaimer.html, style.css, index.html, docs/index.html
**Tags:** legal, privacy, terms, disclaimer, footer, policies

## Website — policy pages + footer — 2026-06-03T20:52:18Z
**Summary:** Created policies/ folder with privacy/index.html, terms/index.html, disclaimer/index.html (clean URLs: /policies/privacy/, /policies/terms/, /policies/disclaimer/). policies/index.html is a listing page with clickable cards for all three. Moved footer CSS from index.html local style to style.css (with margin: 0 auto added). Added .footer-nav CSS to style.css. Updated index.html footer with policy links. Added footer to docs/index.html. All 3 policy pages share the same layout/nav/burger/footer pattern and have full meta+OG+JSON-LD heads.
**Files:** policies/index.html, policies/privacy/index.html, policies/terms/index.html, policies/disclaimer/index.html, style.css, index.html, docs/index.html
**Tags:** legal, privacy, terms, disclaimer, footer, policies, clean-urls


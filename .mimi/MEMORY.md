## Website — nav alignment fix — 2026-06-03T18:45:47Z
**Summary:** Fixed docs page nav misalignment. Root cause: docs/index.html had unscoped `li { margin-bottom: 8px }` and `a { text-underline-offset: 3px }` element selectors that leaked into .nav-links li, inflating nav height and shifting text downward. Fix: scoped ALL broad element selectors in docs/index.html local <style> to .content (e.g. .content li, .content a, .content p, etc.). Also expanded sidebar-nav a transition from `all 0.15s` to explicit properties.
**Files:** docs/index.html, index.html, style.css
**Tags:** css, nav, specificity, scoping, docs


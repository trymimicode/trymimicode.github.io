#!/usr/bin/env python3
"""
build_languages.py

Fetches language packs from trymimicode/language-packs and regenerates:
  languages/index.html          — listing page
  languages/<name>/index.html   — per-language detail page

Run from the repo root:
  python3 scripts/build_languages.py

Set GITHUB_TOKEN env var to raise the API rate limit.
Requires: pip install markdown
"""

import base64
import html
import json
import os
import sys
import urllib.request

try:
    import markdown as _md
    def render_md(text):
        return _md.markdown(text, extensions=["fenced_code", "tables"])
except ImportError:
    sys.exit("Error: 'markdown' package not found. Run: pip install markdown")

# ── Config ───────────────────────────────────────────────────────────────────

REPO      = "trymimicode/language-packs"
LANG_PATH = "languages"
API_BASE  = f"https://api.github.com/repos/{REPO}/contents/{LANG_PATH}"
SITE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ── GitHub API helpers ────────────────────────────────────────────────────────

def _headers():
    h = {
        "Accept":     "application/vnd.github+json",
        "User-Agent": "mimicode-site-builder",
    }
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        h["Authorization"] = f"Bearer {token}"
    return h


def fetch_json(url):
    req = urllib.request.Request(url, headers=_headers())
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


def fetch_file_content(url):
    """Fetch a file entry from the GitHub contents API, return decoded text."""
    data = fetch_json(url)
    return base64.b64decode(data["content"]).decode("utf-8")


# ── File rendering ────────────────────────────────────────────────────────────

def render_file(fname, content):
    """
    Return an HTML string for the file content block.
    Markdown files are rendered to HTML; everything else is a <pre> block.
    """
    if fname.endswith(".md"):
        return f'<div class="md-body">{render_md(content)}</div>'
    return f'<pre>{html.escape(content)}</pre>'


# ── Description extraction ────────────────────────────────────────────────────

def extract_description(files):
    """
    Pull a one-line description for the listing card.
    Tries RULES.md first, then any .md file.
    Returns the first non-blank, non-heading paragraph line found.
    """
    candidates = sorted(files.keys(), key=lambda n: (n != "RULES.md", n))
    for name in candidates:
        if not name.endswith(".md"):
            continue
        for line in files[name].splitlines():
            stripped = line.strip()
            if stripped and not stripped.startswith("#") and not stripped.startswith("---"):
                return stripped
    return f"{list(files.keys())[0] if files else ''} language pack."


# ── Shared HTML blocks ────────────────────────────────────────────────────────

NAV = """\
      <ul class="nav-links" id="navLinks">
        <li><a href="/">home</a></li>
        <li><a href="/docs/">docs</a></li>
        <li><a href="/languages/" class="active">langs</a></li>
        <li><a href="https://github.com/trymimicode/mimicode-go" target="_blank" rel="noopener">github</a></li>
      </ul>"""

HEADER_BLOCK = """\
  <header>
    <nav>
      <a class="nav-logo" href="/">mimicode</a>
      <button class="nav-burger" id="navBurger" aria-label="Open menu" aria-expanded="false">
        <span></span>
        <span></span>
        <span></span>
      </button>
{nav}
    </nav>
  </header>""".format(nav=NAV)

FOOTER_BLOCK = """\
  <footer>
    <span>mimicode &copy; 2026</span>
    <nav class="footer-nav">
      <a href="/policies/privacy/">privacy</a>
      <a href="/policies/terms/">terms</a>
      <a href="/policies/disclaimer/">disclaimer</a>
    </nav>
  </footer>"""

BURGER_SCRIPT = """\
  <script>
    const hdr = document.querySelector('header');
    const onScroll = () => hdr.classList.toggle('scrolled', window.scrollY > 0);
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();

    const burger   = document.getElementById('navBurger');
    const navLinks = document.getElementById('navLinks');

    function closeMenu() {
      burger.classList.remove('open');
      navLinks.classList.remove('open');
      burger.setAttribute('aria-expanded', 'false');
    }

    burger.addEventListener('click', e => {
      e.stopPropagation();
      const opening = !burger.classList.contains('open');
      opening ? (burger.classList.add('open'), navLinks.classList.add('open'), burger.setAttribute('aria-expanded', 'true'))
              : closeMenu();
    });

    navLinks.querySelectorAll('a').forEach(a => a.addEventListener('click', closeMenu));
    document.addEventListener('click', e => { if (!e.target.closest('nav')) closeMenu(); });
  </script>"""


# ── Page generators ───────────────────────────────────────────────────────────

def listing_page(lang_names):
    """Generate languages/index.html listing all language packs."""

    cards = ""
    for name in sorted(lang_names):
        cards += f"""\
      <a class="lang-item" href="/languages/{name}/">
        <div class="lang-item-header">
          <h2>{html.escape(name)}</h2>
          <span class="lang-arrow" aria-hidden="true">&#8594;</span>
        </div>
        <p>{html.escape(lang_names[name])}</p>
        <div class="lang-tag">{html.escape(name)} pack</div>
      </a>\n\n"""

    return f"""\
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <!-- ── Primary SEO ── -->
  <title>Languages &mdash; mimicode</title>
  <meta name="description" content="Language packs for mimicode. Install rules and agent instructions for your stack with a single command.">
  <meta name="robots" content="index, follow">
  <meta name="author" content="mimicode">
  <link rel="canonical" href="https://mimicode.xyz/languages/">

  <!-- ── Open Graph ── -->
  <meta property="og:type" content="website">
  <meta property="og:url" content="https://mimicode.xyz/languages/">
  <meta property="og:site_name" content="mimicode">
  <meta property="og:title" content="Languages &mdash; mimicode">
  <meta property="og:description" content="Language packs for mimicode. Install rules and agent instructions for your stack with a single command.">
  <meta property="og:image" content="https://mimicode.xyz/assets/embed.png">

  <!-- ── App / Browser ── -->
  <meta name="theme-color" content="#0a0a0b">
  <link rel="icon" type="image/png" href="../assets/templogomimicode.png">

  <!-- ── Structured data ── -->
  <script type="application/ld+json">
  {{
    "@context": "https://schema.org",
    "@type": "CollectionPage",
    "name": "Languages — mimicode",
    "description": "Language packs for mimicode.",
    "url": "https://mimicode.xyz/languages/",
    "isPartOf": {{ "@type": "WebSite", "name": "mimicode", "url": "https://mimicode.xyz" }}
  }}
  </script>

  <link rel="stylesheet" href="../style.css">
  <style>
    main {{
      flex: 1;
      width: 100%;
      max-width: 720px;
      margin: 0 auto;
      padding: 72px 24px 120px;
    }}

    .eyebrow {{
      font-size: 11px;
      font-weight: 500;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--subtle);
      margin-bottom: 14px;
    }}

    .page-header {{
      margin-bottom: 56px;
      padding-bottom: 32px;
      border-bottom: 1px solid var(--border);
    }}

    .page-header h1 {{
      font-size: clamp(30px, 5vw, 46px);
      font-weight: 700;
      letter-spacing: -0.03em;
      line-height: 1.1;
      color: var(--text);
      margin-bottom: 12px;
    }}

    .page-header p {{
      font-size: 15px;
      color: var(--muted);
      line-height: 1.7;
    }}

    .lang-list {{
      display: flex;
      flex-direction: column;
    }}

    .lang-item {{
      display: flex;
      flex-direction: column;
      gap: 6px;
      padding: 28px 0;
      border-bottom: 1px solid var(--border);
      text-decoration: none;
      cursor: pointer;
    }}

    .lang-item:first-child {{ border-top: 1px solid var(--border); }}

    .lang-item-header {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
    }}

    .lang-item h2 {{
      font-size: 17px;
      font-weight: 600;
      letter-spacing: -0.01em;
      color: var(--text);
      transition: color 0.15s;
    }}

    .lang-item:hover h2 {{ opacity: 0.8; }}

    .lang-arrow {{
      font-size: 16px;
      color: var(--subtle);
      transition: transform 0.2s, color 0.15s;
      flex-shrink: 0;
    }}

    .lang-item:hover .lang-arrow {{
      transform: translateX(4px);
      color: var(--muted);
    }}

    .lang-item p {{
      font-size: 14px;
      color: var(--muted);
      line-height: 1.7;
      margin: 0;
    }}

    .lang-tag {{
      font-size: 11px;
      font-weight: 500;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      color: var(--subtle);
      margin-top: 4px;
    }}
  </style>
</head>
<body>

{HEADER_BLOCK}

  <main>
    <div class="page-header">
      <div class="eyebrow">Language Packs</div>
      <h1>Languages</h1>
      <p>Rules and agent instructions for your stack. Install any pack with <code style="font-family:var(--font-mono);font-size:13px;background:var(--surface2);border:1px solid var(--border);border-radius:4px;padding:2px 6px">mimicode install &lt;language&gt;</code>.</p>
    </div>

    <nav class="lang-list" aria-label="Language packs">

{cards}\
    </nav>
  </main>

{FOOTER_BLOCK}

{BURGER_SCRIPT}

</body>
</html>
"""


def detail_page(name, files):
    """Generate languages/<name>/index.html for a single language pack."""

    sorted_files = sorted(files.keys(), key=lambda n: (n != "RULES.md", n != "AGENTS.md", n))

    dropdowns = ""
    for fname in sorted_files:
        rendered = render_file(fname, files[fname])
        label = "Coding conventions and standards" if fname == "RULES.md" else \
                "Agent behavior instructions"      if fname == "AGENTS.md" else \
                "Pack file"
        dropdowns += f"""\
      <details>
        <summary>
          <div class="summary-left">
            <span class="summary-name">{html.escape(fname)}</span>
            <span class="summary-desc">{label}</span>
          </div>
          <span class="summary-chevron" aria-hidden="true">&#8250;</span>
        </summary>
        <div class="file-content">
          {rendered}
        </div>
      </details>\n\n"""

    return f"""\
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <!-- ── Primary SEO ── -->
  <title>{html.escape(name)} language pack &mdash; mimicode</title>
  <meta name="description" content="{html.escape(name)} language pack for mimicode. Rules and agent instructions.">
  <meta name="robots" content="index, follow">
  <meta name="author" content="mimicode">
  <link rel="canonical" href="https://mimicode.xyz/languages/{html.escape(name)}/">

  <!-- ── Open Graph ── -->
  <meta property="og:type" content="website">
  <meta property="og:url" content="https://mimicode.xyz/languages/{html.escape(name)}/">
  <meta property="og:site_name" content="mimicode">
  <meta property="og:title" content="{html.escape(name)} language pack &mdash; mimicode">
  <meta property="og:description" content="{html.escape(name)} language pack for mimicode. Rules and agent instructions.">
  <meta property="og:image" content="https://mimicode.xyz/assets/embed.png">

  <!-- ── App / Browser ── -->
  <meta name="theme-color" content="#0a0a0b">
  <link rel="icon" type="image/png" href="../../assets/templogomimicode.png">

  <!-- ── Structured data ── -->
  <script type="application/ld+json">
  {{
    "@context": "https://schema.org",
    "@type": "WebPage",
    "name": "{html.escape(name)} language pack — mimicode",
    "description": "{html.escape(name)} language pack for mimicode.",
    "url": "https://mimicode.xyz/languages/{html.escape(name)}/",
    "isPartOf": {{ "@type": "WebSite", "name": "mimicode", "url": "https://mimicode.xyz" }}
  }}
  </script>

  <link rel="stylesheet" href="../../style.css">
  <style>
    main {{
      flex: 1;
      width: 100%;
      max-width: 720px;
      margin: 0 auto;
      padding: 72px 24px 120px;
    }}

    .eyebrow {{
      font-size: 11px;
      font-weight: 500;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--subtle);
      margin-bottom: 14px;
    }}

    .pack-header {{
      margin-bottom: 48px;
      padding-bottom: 32px;
      border-bottom: 1px solid var(--border);
    }}

    .pack-header h1 {{
      font-size: clamp(30px, 5vw, 46px);
      font-weight: 700;
      letter-spacing: -0.03em;
      line-height: 1.1;
      color: var(--text);
      margin-bottom: 12px;
    }}

    /* ── Dropdowns ── */
    .file-list {{
      display: flex;
      flex-direction: column;
      margin-bottom: 48px;
    }}

    details {{
      border-bottom: 1px solid var(--border);
    }}

    details:first-child {{
      border-top: 1px solid var(--border);
    }}

    summary {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      padding: 22px 0;
      cursor: pointer;
      list-style: none;
      user-select: none;
    }}

    summary::-webkit-details-marker {{ display: none; }}

    .summary-left {{
      display: flex;
      flex-direction: column;
      gap: 3px;
    }}

    .summary-name {{
      font-size: 16px;
      font-weight: 600;
      letter-spacing: -0.01em;
      color: var(--text);
    }}

    .summary-desc {{
      font-size: 13px;
      color: var(--subtle);
    }}

    .summary-chevron {{
      font-size: 13px;
      color: var(--subtle);
      transition: transform 0.2s;
      flex-shrink: 0;
    }}

    details[open] .summary-chevron {{ transform: rotate(90deg); }}

    .file-content {{
      padding-bottom: 28px;
    }}

    /* ── Rendered markdown (scoped to .md-body) ── */

    .md-body {{
      color: var(--muted);
      font-size: 14px;
      line-height: 1.8;
    }}

    .md-body h1 {{
      font-size: 18px;
      font-weight: 700;
      letter-spacing: -0.02em;
      color: var(--text);
      margin: 0 0 12px;
    }}

    .md-body h2 {{
      font-size: 14px;
      font-weight: 600;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      color: var(--subtle);
      margin: 28px 0 10px;
      padding-bottom: 6px;
      border-bottom: 1px solid var(--border);
    }}

    .md-body h3 {{
      font-size: 13px;
      font-weight: 600;
      color: var(--muted);
      margin: 20px 0 8px;
    }}

    .md-body p {{
      margin: 0 0 12px;
    }}

    .md-body p:last-child {{ margin-bottom: 0; }}

    .md-body hr {{
      border: none;
      border-top: 1px solid var(--border);
      margin: 24px 0;
    }}

    .md-body ul,
    .md-body ol {{
      margin: 0 0 12px;
      padding-left: 20px;
    }}

    .md-body li {{
      margin-bottom: 4px;
    }}

    .md-body strong {{
      font-weight: 600;
      color: var(--text);
    }}

    .md-body em {{
      font-style: italic;
    }}

    .md-body code {{
      font-family: var(--font-mono);
      font-size: 12px;
      color: var(--text);
      background: var(--surface2);
      border: 1px solid var(--border);
      border-radius: 4px;
      padding: 1px 5px;
    }}

    .md-body pre {{
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 16px 18px;
      margin: 12px 0 16px;
      overflow-x: auto;
    }}

    .md-body pre code {{
      font-family: var(--font-mono);
      font-size: 12px;
      line-height: 1.7;
      color: var(--muted);
      background: none;
      border: none;
      border-radius: 0;
      padding: 0;
    }}

    .md-body table {{
      width: 100%;
      border-collapse: collapse;
      margin: 12px 0 16px;
      font-size: 13px;
    }}

    .md-body th {{
      text-align: left;
      font-weight: 600;
      color: var(--text);
      padding: 8px 12px;
      border-bottom: 1px solid var(--border-hover);
    }}

    .md-body td {{
      padding: 8px 12px;
      border-bottom: 1px solid var(--border);
      color: var(--muted);
      vertical-align: top;
    }}

    .md-body tr:last-child td {{ border-bottom: none; }}

    /* raw file fallback */
    .file-content > pre {{
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 20px 22px;
      overflow-x: auto;
      font-family: var(--font-mono);
      font-size: 12px;
      line-height: 1.75;
      color: var(--muted);
      white-space: pre-wrap;
      word-break: break-word;
    }}

    /* ── Install block ── */
    .install-block {{
      border-top: 1px solid var(--border);
      padding-top: 40px;
    }}

    .install-label {{
      font-size: 11px;
      font-weight: 500;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--subtle);
      margin-bottom: 14px;
    }}

    .install-cmd {{
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 14px 18px;
    }}

    .install-cmd code {{
      font-family: var(--font-mono);
      font-size: 14px;
      color: var(--text);
      letter-spacing: 0.01em;
      background: none;
      border: none;
      padding: 0;
    }}

    .copy-btn {{
      background: none;
      border: 1px solid var(--border);
      border-radius: 6px;
      color: var(--subtle);
      cursor: pointer;
      font-size: 12px;
      font-family: inherit;
      padding: 5px 12px;
      transition: border-color 0.15s, color 0.15s;
      white-space: nowrap;
      flex-shrink: 0;
    }}

    .copy-btn:hover {{
      border-color: var(--border-hover);
      color: var(--muted);
    }}
  </style>
</head>
<body>

{HEADER_BLOCK}

  <main>
    <div class="pack-header">
      <div class="eyebrow">Language Pack</div>
      <h1>{html.escape(name)}</h1>
    </div>

    <div class="file-list">

{dropdowns}\
    </div>

    <div class="install-block">
      <div class="install-label">Install</div>
      <div class="install-cmd">
        <code id="installCmd">mimicode install {html.escape(name)}</code>
        <button class="copy-btn" id="copyBtn" type="button">copy</button>
      </div>
    </div>
  </main>

{FOOTER_BLOCK}

  <script>
    const hdr = document.querySelector('header');
    const onScroll = () => hdr.classList.toggle('scrolled', window.scrollY > 0);
    window.addEventListener('scroll', onScroll, {{ passive: true }});
    onScroll();

    const burger   = document.getElementById('navBurger');
    const navLinks = document.getElementById('navLinks');

    function closeMenu() {{
      burger.classList.remove('open');
      navLinks.classList.remove('open');
      burger.setAttribute('aria-expanded', 'false');
    }}

    burger.addEventListener('click', e => {{
      e.stopPropagation();
      const opening = !burger.classList.contains('open');
      opening ? (burger.classList.add('open'), navLinks.classList.add('open'), burger.setAttribute('aria-expanded', 'true'))
              : closeMenu();
    }});

    navLinks.querySelectorAll('a').forEach(a => a.addEventListener('click', closeMenu));
    document.addEventListener('click', e => {{ if (!e.target.closest('nav')) closeMenu(); }});

    document.getElementById('copyBtn').addEventListener('click', async () => {{
      const cmd = document.getElementById('installCmd').textContent;
      try {{
        await navigator.clipboard.writeText(cmd);
        const btn = document.getElementById('copyBtn');
        btn.textContent = 'copied';
        setTimeout(() => {{ btn.textContent = 'copy'; }}, 1800);
      }} catch (err) {{}}
    }});
  </script>

</body>
</html>
"""


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print(f"Fetching language list from {API_BASE} ...")
    entries = fetch_json(API_BASE)
    lang_dirs = [e for e in entries if e["type"] == "dir"]

    if not lang_dirs:
        print("No language folders found. Exiting.")
        sys.exit(0)

    lang_data = {}
    for entry in lang_dirs:
        name = entry["name"]
        print(f"  Fetching {name}/ ...")
        file_entries = fetch_json(entry["url"])
        files = {}
        for fe in file_entries:
            if fe["type"] == "file":
                print(f"    {fe['name']}")
                files[fe["name"]] = fetch_file_content(fe["url"])
        lang_data[name] = files

    descriptions = {name: extract_description(files) for name, files in lang_data.items()}

    listing_path = os.path.join(SITE_ROOT, "languages", "index.html")
    os.makedirs(os.path.dirname(listing_path), exist_ok=True)
    with open(listing_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(listing_page(descriptions))
    print(f"Wrote {listing_path}")

    for name, files in lang_data.items():
        detail_path = os.path.join(SITE_ROOT, "languages", name, "index.html")
        os.makedirs(os.path.dirname(detail_path), exist_ok=True)
        with open(detail_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(detail_page(name, files))
        print(f"Wrote {detail_path}")

    print("Done.")


if __name__ == "__main__":
    main()

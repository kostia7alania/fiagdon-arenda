"""Check the exported static site before activating a release."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
import re
import sys
import xml.etree.ElementTree as ET


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.refs = []
        self.images = 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if attrs.get('id'):
            self.ids.add(attrs['id'])
        self.images += tag == 'img'
        for key in ('href', 'src', 'action', 'data-src'):
            if attrs.get(key):
                self.refs.append((tag, key, attrs[key]))


root = Path(sys.argv[1]).resolve()
page = Page()
page.feed((root / 'index.html').read_text())
errors = []


def check_url(value, parent, allow_fragment=False):
    parsed = urlsplit(value.strip())
    if parsed.scheme or parsed.netloc:
        return
    if not parsed.path:
        if allow_fragment and parsed.fragment and parsed.fragment not in page.ids:
            errors.append('Missing anchor: ' + value)
        return
    target = (root / unquote(parsed.path.lstrip('/')) if parsed.path.startswith('/')
              else parent / unquote(parsed.path)).resolve()
    if root not in target.parents and target != root:
        errors.append('Resource leaves site root: ' + value)
    elif not target.is_file():
        errors.append('Missing resource: ' + value)


for tag, attr, value in page.refs:
    check_url(value, root, allow_fragment=True)
    parsed = urlsplit(value)
    if (parsed.scheme in ('http', 'https') or parsed.netloc) and (
        attr == 'src' or tag == 'link'
    ):
        errors.append('External runtime dependency: ' + value)

for css in root.rglob('*.css'):
    if not css.is_file():
        continue
    text = css.read_text(errors='replace')
    if 'fonts.googleapis.com' in text:
        errors.append('External Google Fonts in ' + str(css.relative_to(root)))
    for value in re.findall(r'url\(\s*["\x27]?([^\)"\x27]+)', text):
        check_url(value, css.parent)

ET.fromstring((root / 'sitemap.xml').read_text())
if not page.images:
    errors.append('No images in the landing page')
if errors:
    raise SystemExit('\n'.join(errors))
print(f'Static validation passed: {len(page.refs)} HTML references; {page.images} images')

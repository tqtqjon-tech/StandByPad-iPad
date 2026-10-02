import hashlib
import pathlib
import sys

assets = pathlib.Path(sys.argv[1])
source = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else None
required = ['index.html', 'desktop-overlay.js', 'manifest.webmanifest', 'sw.js',
            'bg_image.png', 'icon.svg', 'SF-Pro-Rounded-Black-jNh6tqG1.woff2',
            'AFCamberwell-One-Regular-B2Lu_sey.otf']
for name in required:
    path = assets / name
    assert path.is_file() and path.stat().st_size > 0, f'Missing asset: {path}'
    if source:
        assert hashlib.sha256(path.read_bytes()).digest() == hashlib.sha256((source / name).read_bytes()).digest(), f'Asset changed: {name}'
print(f'Validated {len(required)} bundled web assets in {assets}')

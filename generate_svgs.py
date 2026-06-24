import os

os.makedirs('assets', exist_ok=True)

svgs = {
    'player.svg': '''<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
<rect x="8" y="8" width="48" height="48" rx="12" fill="#2d52a3" stroke="#1d3772" stroke-width="4"/>
<circle cx="32" cy="32" r="12" fill="#5c8df5"/>
<rect x="44" y="24" width="12" height="16" rx="4" fill="#f5d44f"/>
</svg>''',

    'nexus.svg': '''<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
<rect x="4" y="4" width="56" height="56" rx="8" fill="#3a3a3a" stroke="#222" stroke-width="4"/>
<path d="M 32 12 L 52 32 L 32 52 L 12 32 Z" fill="#9d4edd"/>
<circle cx="32" cy="32" r="8" fill="#e0aaff"/>
</svg>''',

    'enemy.svg': '''<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
<circle cx="32" cy="32" r="16" fill="#d90429" stroke="#8d0801" stroke-width="4"/>
<line x1="32" y1="32" x2="12" y2="12" stroke="#8d0801" stroke-width="4" stroke-linecap="round"/>
<line x1="32" y1="32" x2="52" y2="12" stroke="#8d0801" stroke-width="4" stroke-linecap="round"/>
<line x1="32" y1="32" x2="12" y2="52" stroke="#8d0801" stroke-width="4" stroke-linecap="round"/>
<line x1="32" y1="32" x2="52" y2="52" stroke="#8d0801" stroke-width="4" stroke-linecap="round"/>
<circle cx="40" cy="24" r="4" fill="#ffb703"/>
<circle cx="40" cy="40" r="4" fill="#ffb703"/>
</svg>''',

    'belt.svg': '''<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
<rect x="0" y="8" width="64" height="48" fill="#4a4a4a"/>
<path d="M 16 16 L 32 32 L 16 48" fill="none" stroke="#fca311" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M 36 16 L 52 32 L 36 48" fill="none" stroke="#fca311" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''',

    'miner.svg': '''<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
<rect x="4" y="4" width="56" height="56" rx="8" fill="#e07a5f" stroke="#813405" stroke-width="4"/>
<circle cx="32" cy="32" r="16" fill="#3d405b"/>
<path d="M 32 8 L 36 16 L 44 16 L 38 24 L 42 32 L 32 28 L 22 32 L 26 24 L 20 16 L 28 16 Z" fill="#f2cc8f" transform="rotate(90 32 32)"/>
<rect x="52" y="24" width="12" height="16" fill="#813405"/>
</svg>''',

    'turret.svg': '''<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
<rect x="8" y="8" width="48" height="48" rx="24" fill="#3a5a40" stroke="#132a13" stroke-width="4"/>
<rect x="32" y="24" width="32" height="16" fill="#132a13"/>
<circle cx="32" cy="32" r="12" fill="#a3b18a"/>
</svg>''',

    'processor.svg': '''<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
<rect x="4" y="4" width="56" height="56" fill="#e5989b" stroke="#6d597a" stroke-width="4"/>
<circle cx="20" cy="20" r="8" fill="#6d597a"/>
<circle cx="44" cy="44" r="12" fill="#6d597a"/>
<rect x="24" y="24" width="16" height="16" fill="#ffb4a2"/>
</svg>''',

    'splitter.svg': '''<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
<rect x="4" y="4" width="56" height="56" rx="8" fill="#9d4edd" stroke="#3c096c" stroke-width="4"/>
<path d="M 24 16 L 40 16 L 32 8 Z" fill="#fff"/>
<path d="M 48 24 L 56 32 L 48 40 Z" fill="#fff"/>
<path d="M 24 48 L 40 48 L 32 56 Z" fill="#fff"/>
<circle cx="32" cy="32" r="8" fill="#5a189a"/>
</svg>''',

    'ore.svg': '''<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
<path d="M 12 24 L 28 8 L 44 20 L 56 36 L 40 56 L 20 48 Z" fill="#6b705c" stroke="#3f4238" stroke-width="2"/>
<path d="M 20 28 L 32 16 L 44 28 L 36 44 L 24 40 Z" fill="#a5a58d"/>
</svg>''',

    'tree.svg': '''<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
<circle cx="32" cy="32" r="24" fill="#2d6a4f" stroke="#081c15" stroke-width="2"/>
<circle cx="24" cy="24" r="12" fill="#40916c"/>
<circle cx="44" cy="36" r="10" fill="#52b788"/>
</svg>''',

    'rock.svg': '''<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
<path d="M 16 32 Q 24 16 40 20 T 56 40 Q 48 56 32 52 T 16 32 Z" fill="#8d99ae" stroke="#2b2d42" stroke-width="2"/>
</svg>'''
}

for name, content in svgs.items():
    with open(f'assets/{name}', 'w') as f:
        f.write(content)

print("SVG files generated successfully.")

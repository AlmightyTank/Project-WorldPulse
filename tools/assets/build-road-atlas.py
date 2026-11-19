"""Derive WorldPulse's road atlas from Kenney City Kit Roads 2.2 (CC0).

Source: https://kenney.nl/assets/city-kit-roads (Kenney, CC0-1.0).
Run from any directory with Python and Pillow. Only asphalt/shoulder swatches
change; the source atlas and GLBs remain untouched. Assertions guard pack drift.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "game/godot/assets/third_party/kenney/city-kit-roads/models/Textures/colormap.png"
OUTPUT = ROOT / "game/godot/assets/materials/roads/colormap.png"
REPLACEMENTS = {(102, 107, 128, 255): (58, 60, 63, 255), (81, 85, 102, 255): (45, 47, 50, 255)}


def main():
    image = Image.open(SOURCE).convert("RGBA")
    assert image.size == (512, 512), "Review UV swatches after updating the source pack"
    pixels = list(image.getdata())
    assert pixels.count((102, 107, 128, 255)) == 8192
    assert pixels.count((81, 85, 102, 255)) == 16384
    corrected = [REPLACEMENTS.get(pixel, pixel) for pixel in pixels]
    assert sum(a != b for a, b in zip(pixels, corrected)) == 24576
    assert all(a == b for a, b in zip(pixels, corrected) if a not in REPLACEMENTS)
    image.putdata(corrected)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT)
    assert list(Image.open(OUTPUT).getdata()) == corrected
    print(f"Wrote {OUTPUT}: 24576 asphalt/shoulder pixels changed; all others preserved")


if __name__ == "__main__":
    main()

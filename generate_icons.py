import cairosvg
import io
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

GRADIENT_TOP_LEFT = (0x2F, 0x9B, 0xF0)
GRADIENT_BOTTOM_RIGHT = (0x0B, 0x3D, 0x91)
BACKGROUND_COLOR = "#1565C0"  # fallback solid, kept for reference
SHADOW_COLOR = (4, 26, 66)
SHADOW_OPACITY = 110
SHADOW_OFFSET = 0.018  # fraction of icon size
SHADOW_BLUR = 0.02  # fraction of icon size


def make_gradient(size):
    small = 256
    img = Image.new("RGB", (small, small))
    px = img.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            px[x, y] = tuple(
                round(a + (b - a) * t)
                for a, b in zip(GRADIENT_TOP_LEFT, GRADIENT_BOTTOM_RIGHT)
            )
    return img.resize((size, size), Image.BICUBIC)


def render_glyph(svg_file, size):
    png_bytes = cairosvg.svg2png(url=svg_file, output_width=size, output_height=size)
    return Image.open(io.BytesIO(png_bytes)).convert("RGBA")


def compose_icon(svg_file, size):
    glyph = render_glyph(svg_file, size)
    icon = make_gradient(size).convert("RGBA")

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    alpha = glyph.getchannel("A").point(lambda a: a * SHADOW_OPACITY // 255)
    shadow.paste((*SHADOW_COLOR, 255), (0, round(size * SHADOW_OFFSET)), alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * SHADOW_BLUR))

    icon.alpha_composite(shadow)
    icon.alpha_composite(glyph)
    return icon


def generate_icon_png(svg_file):
    output_file = svg_file.replace('.svg', '.png')
    compose_icon(svg_file, 2000).save(output_file, "PNG")
    print("Generated", output_file)


def generate_icon_png_for_readme(svg_file):
    readme_dir = Path(__file__).parent / "assets" / "readme"
    output_file = readme_dir / "icon.png"
    icon = compose_icon(svg_file, 2000)
    width, height = icon.size
    radius = int(min(width, height) * 0.25)
    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        [(0, 0), (width, height)],
        radius=radius,
        fill=255
    )
    icon.putalpha(mask)
    icon.save(str(output_file), "PNG")
    print("Generated", output_file)


def generate_adaptive_foreground(svg_file):
    base_name = os.path.splitext(svg_file)[0]
    output_file = f"{base_name}-foreground-432x432.png"

    cairosvg.svg2png(
        url=svg_file,
        write_to=output_file,
        output_width=432,
        output_height=432,
    )
    print("Generated", output_file)


def generate_adaptive_monochrome(svg_file):
    base_name = os.path.splitext(svg_file)[0]
    output_file = f"{base_name}-monochrome-432x432.png"

    cairosvg.svg2png(
        url=svg_file,
        write_to=output_file,
        output_width=432,
        output_height=432,
    )
    img = Image.open(output_file).convert("RGBA")
    mono_img = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    for x in range(432):
        for y in range(432):
            r, g, b, a = img.getpixel((x, y))
            if a > 0:
                mono_img.putpixel((x, y), (255, 255, 255, a))

    mono_img.save(output_file, "PNG")
    print("Generated", output_file)


def generate_adaptive_background(svg_file):
    base_name = os.path.splitext(svg_file)[0]
    output_file = f"{base_name}-background.png"

    make_gradient(432).save(output_file, "PNG")
    print("Generated", output_file)


def main():
    svg_file = str(Path(__file__).parent / "assets" / "icon.svg")
    generate_icon_png(svg_file)
    generate_icon_png_for_readme(svg_file)
    generate_adaptive_foreground(svg_file)
    generate_adaptive_monochrome(svg_file)
    generate_adaptive_background(svg_file)

if __name__ == "__main__":
    main()

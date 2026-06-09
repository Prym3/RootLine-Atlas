from pathlib import Path
from PIL import Image

def convert_png_to_ico(png_path: str, ico_path: str) -> None:
    img = Image.open(png_path)
    
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    icon_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    icons = []
    
    for w, h in icon_sizes:
        resized = img.resize((w, h), Image.Resampling.LANCZOS)
        icons.append(resized)
    
    icons[0].save(ico_path, format='ICO', sizes=icon_sizes, append_images=icons[1:])
    print(f"Converted: {png_path} -> {ico_path}")

if __name__ == "__main__":
    base_dir = Path(__file__).parent
    png_file = base_dir / "44c5b14a-ec80-4a10-bed2-01ad88c608a6.png"
    ico_file = base_dir / "app_icon.ico"
    
    if png_file.exists():
        convert_png_to_ico(str(png_file), str(ico_file))
    else:
        print(f"PNG file not found: {png_file}")

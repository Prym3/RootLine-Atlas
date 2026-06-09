from PIL import Image, ImageDraw
import math

SIZES = [16, 24, 32, 48, 64, 128, 256]

def draw_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = size

    FOLDER_DARK  = (78,  82, 200, 255)
    FOLDER_MID   = (99, 108, 230, 255)
    FOLDER_LIGHT = (130, 140, 255, 255)
    SHADOW       = (40,  40, 100, 80)

    pad  = max(1, s // 16)
    r    = max(2, s // 12)

    tx1 = int(s * 0.06)
    tx2 = int(s * 0.46)
    ty1 = int(s * 0.20)
    ty2 = int(s * 0.32)
    d.rounded_rectangle([tx1, ty1, tx2, ty2], radius=max(1, r//2), fill=FOLDER_LIGHT)

    fx1 = int(s * 0.06)
    fx2 = int(s * 0.88)
    fy1 = int(s * 0.28)
    fy2 = int(s * 0.82)
    d.rounded_rectangle([fx1, fy1, fx2, fy2], radius=r, fill=FOLDER_MID)

    hl_h = max(1, s // 20)
    d.rounded_rectangle([fx1+pad, fy1+pad, fx2-pad, fy1+pad+hl_h],
                        radius=max(1, r//2), fill=FOLDER_LIGHT)

    edge_top = fy2 - max(2, s // 18)
    edge_bot = fy2 - pad
    if edge_bot > edge_top:
        d.rounded_rectangle([fx1+pad, edge_top, fx2-pad, edge_bot],
                            radius=max(1, r//2), fill=FOLDER_DARK)

    cx = int(s * 0.60)
    cy = int(s * 0.60)
    glass_r = int(s * 0.22)
    ring_w  = max(2, s // 18)

    d.ellipse([cx - glass_r + 2, cy - glass_r + 2,
               cx + glass_r + 2, cy + glass_r + 2], fill=SHADOW)

    d.ellipse([cx - glass_r, cy - glass_r,
               cx + glass_r, cy + glass_r], fill=(220, 225, 255, 210))

    d.ellipse([cx - glass_r, cy - glass_r,
               cx + glass_r, cy + glass_r],
              outline=(255, 255, 255, 255), width=ring_w)

    angle = math.radians(135)
    hx1 = int(cx + glass_r * 0.75 * math.cos(angle))
    hy1 = int(cy + glass_r * 0.75 * math.sin(angle))
    hx2 = int(cx + (glass_r + int(s * 0.18)) * math.cos(angle))
    hy2 = int(cy + (glass_r + int(s * 0.18)) * math.sin(angle))
    handle_w = max(2, ring_w + 1)
    d.line([hx1+1, hy1+1, hx2+2, hy2+2], fill=SHADOW, width=handle_w+1)
    d.line([hx1, hy1, hx2, hy2], fill=(255, 255, 255, 255), width=handle_w)

    shine_r = max(1, glass_r // 4)
    sx = cx - glass_r // 3
    sy = cy - glass_r // 3
    d.ellipse([sx - shine_r, sy - shine_r, sx + shine_r, sy + shine_r],
              fill=(255, 255, 255, 180))

    return img


frames = [draw_icon(s) for s in SIZES]
frames[0].save(
    "app_icon.ico",
    format="ICO",
    sizes=[(s, s) for s in SIZES],
    append_images=frames[1:],
)
print("Created app_icon.ico")

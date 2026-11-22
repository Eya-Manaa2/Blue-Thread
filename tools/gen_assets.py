"""Generate the 2D assets of BLUE THREAD: THE LAST BLUE (icons, logo, mattes, intro slides).
Everything is derived from the user's reference images or drawn here procedurally."""
import math, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance, ImageOps, ImageChops

P = '/home/claude/proj/assets'
F_BLACK = P + '/fonts/FiraSans-Black.ttf'
F_BOLD = P + '/fonts/FiraSans-Bold.ttf'
F_REG = P + '/fonts/FiraSans-Regular.ttf'
F_AR = '/tmp/DejaVuSans-Bold.ttf'
S = 4  # supersampling


def canvas(w, h):
    return Image.new('RGBA', (w * S, h * S), (0, 0, 0, 0))


def down(im, w, h):
    return im.resize((w, h), Image.LANCZOS)


def rr(d, box, r, fill):
    d.rounded_rectangle([v * S for v in box], radius=r * S, fill=fill)


def poly(d, pts, fill):
    d.polygon([(x * S, y * S) for x, y in pts], fill=fill)


W = (246, 246, 240, 255)

# ---------------------------------------------------------------- bin icons
def icon_paper():
    im = canvas(256, 256); d = ImageDraw.Draw(im)
    poly(d, [(62, 22), (156, 22), (200, 66), (200, 234), (62, 234)], W)
    poly(d, [(156, 22), (156, 66), (200, 66)], (0, 0, 0, 0))
    poly(d, [(150, 22), (150, 72), (200, 72), (200, 64), (158, 64), (158, 22)], (0, 0, 0, 0))
    # cut a little gap around the fold
    for i, y in enumerate([104, 132, 160, 188]):
        rr(d, (88, y, 176 if i < 3 else 140, y + 12), 6, (0, 0, 0, 0))
    return down(im, 256, 256)


def icon_textile():
    im = canvas(256, 256); d = ImageDraw.Draw(im)
    poly(d, [(96, 34), (110, 34), (128, 56), (146, 34), (160, 34), (226, 70), (204, 118), (182, 106),
             (182, 228), (74, 228), (74, 106), (52, 118), (30, 70)], W)
    return down(im, 256, 256)


def icon_pet():
    im = canvas(256, 256); d = ImageDraw.Draw(im)
    rr(d, (106, 14, 150, 42), 6, W)
    rr(d, (110, 44, 146, 72), 4, W)
    poly(d, [(110, 70), (146, 70), (176, 112), (80, 112)], W)
    rr(d, (78, 104, 178, 238), 22, W)
    rr(d, (90, 140, 166, 152), 5, (0, 0, 0, 0))
    rr(d, (90, 186, 166, 198), 5, (0, 0, 0, 0))
    return down(im, 256, 256)


def icon_residual():
    im = canvas(256, 256); d = ImageDraw.Draw(im)
    rr(d, (100, 20, 156, 44), 8, W)
    rr(d, (112, 30, 144, 44), 4, (0, 0, 0, 0))
    rr(d, (44, 44, 212, 68), 8, W)
    poly(d, [(62, 78), (194, 78), (180, 236), (76, 236)], W)
    for x in (98, 128, 158):
        rr(d, (x - 6, 100, x + 6, 214), 6, (0, 0, 0, 0))
    return down(im, 256, 256)


def icon_special():
    im = canvas(256, 256); d = ImageDraw.Draw(im)
    # rounded triangle outline
    pts = [(128, 22), (238, 222), (18, 222)]
    d.line([(x * S, y * S) for x, y in pts + [pts[0]]], fill=W, width=22 * S, joint='curve')
    for x, y in pts:
        d.ellipse([(x - 11) * S, (y - 11) * S, (x + 11) * S, (y + 11) * S], fill=W)
    poly(d, [(140, 78), (96, 150), (126, 150), (112, 200), (162, 124), (132, 124), (148, 78)], W)
    return down(im, 256, 256)


def heart(filled=True):
    im = canvas(128, 128); d = ImageDraw.Draw(im)
    col = (235, 64, 74, 255) if filled else (40, 30, 34, 200)
    d.ellipse([14 * S, 18 * S, 68 * S, 72 * S], fill=col)
    d.ellipse([60 * S, 18 * S, 114 * S, 72 * S], fill=col)
    poly(d, [(16, 54), (112, 54), (64, 114)], col)
    if filled:
        d.ellipse([30 * S, 30 * S, 50 * S, 46 * S], fill=(255, 190, 196, 230))
    else:
        im2 = canvas(128, 128); d2 = ImageDraw.Draw(im2)
        d2.ellipse([24 * S, 28 * S, 62 * S, 66 * S], fill=(255, 255, 255, 255))
        d2.ellipse([66 * S, 28 * S, 104 * S, 66 * S], fill=(255, 255, 255, 255))
        poly(d2, [(28, 56), (100, 56), (64, 100)], (255, 255, 255, 255))
        hole = im2.split()[3]
        a = im.split()[3]
        a = ImageChops.subtract(a, hole.point(lambda v: int(v * 0.75)))
        im.putalpha(a)
        im = Image.alpha_composite(Image.new('RGBA', im.size, (0, 0, 0, 0)), im)
        # outline tint
        r, g, b, a = im.split()
        im = Image.merge('RGBA', (r.point(lambda v: 150), g.point(lambda v: 160), b.point(lambda v: 175), a))
    return down(im, 128, 128)


def o2_icon():
    im = canvas(128, 128); d = ImageDraw.Draw(im)
    rr(d, (40, 18, 88, 118), 22, (214, 220, 226, 255))
    rr(d, (40, 62, 88, 80), 2, (240, 196, 40, 255))
    rr(d, (54, 6, 74, 22), 4, (120, 128, 136, 255))
    f = ImageFont.truetype(F_BLACK, 24 * S)
    d.text((64 * S, 42 * S), 'O2', font=f, fill=(40, 50, 60, 255), anchor='mm')
    return down(im, 128, 128)


def star(filled=True):
    im = canvas(128, 128); d = ImageDraw.Draw(im)
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 58 if i % 2 == 0 else 25
        pts.append((64 + r * math.cos(a), 66 + r * math.sin(a)))
    poly(d, pts, (255, 206, 64, 255) if filled else (60, 66, 80, 210))
    return down(im, 128, 128)


def check_icon(ok=True):
    im = canvas(128, 128); d = ImageDraw.Draw(im)
    d.ellipse([6 * S, 6 * S, 122 * S, 122 * S], fill=(46, 196, 120, 255) if ok else (226, 66, 70, 255))
    if ok:
        d.line([(36 * S, 66 * S), (56 * S, 86 * S), (94 * S, 44 * S)], fill=W, width=14 * S, joint='curve')
    else:
        d.line([(42 * S, 42 * S), (86 * S, 86 * S)], fill=W, width=14 * S)
        d.line([(86 * S, 42 * S), (42 * S, 86 * S)], fill=W, width=14 * S)
    return down(im, 128, 128)


def dot():
    im = canvas(64, 64); d = ImageDraw.Draw(im)
    d.ellipse([4 * S, 4 * S, 60 * S, 60 * S], fill=W)
    return down(im, 64, 64)


def glow_sprite():
    im = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
    px = im.load()
    for y in range(128):
        for x in range(128):
            r = math.hypot(x - 63.5, y - 63.5) / 64.0
            a = max(0.0, 1.0 - r) ** 2.2
            px[x, y] = (255, 255, 255, int(255 * a))
    return im


def smoke_sprite():
    random.seed(7)
    im = Image.new('L', (256, 256), 0)
    d = ImageDraw.Draw(im)
    for _ in range(60):
        x = random.gauss(128, 34); y = random.gauss(128, 34); r = random.uniform(18, 52)
        d.ellipse([x - r, y - r, x + r, y + r], fill=random.randint(40, 110))
    im = im.filter(ImageFilter.GaussianBlur(14))
    mask = Image.new('L', (256, 256), 0)
    ImageDraw.Draw(mask).ellipse([18, 18, 238, 238], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(26))
    im = ImageChops.multiply(im, mask)
    im = ImageOps.autocontrast(im)
    out = Image.new('RGBA', (256, 256), (255, 255, 255, 0))
    out.putalpha(im)
    return out


# ---------------------------------------------------------------- logo
def logo():
    w, h = 1400, 520
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    f = ImageFont.truetype(F_BLACK, 190)
    text = 'BLUE THREAD'
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).text((w // 2, 175), text, font=f, fill=255, anchor='mm')
    # vertical gradient fill
    grad = Image.new('RGBA', (w, h))
    gd = ImageDraw.Draw(grad)
    for y in range(h):
        t = min(1.0, max(0.0, (y - 80) / 190.0))
        c = (int(170 + (20 - 170) * t), int(240 + (128 - 240) * t), int(255 + (214 - 255) * t), 255)
        gd.line([(0, y), (w, y)], fill=c)
    glow = Image.new('RGBA', (w, h), (40, 170, 255, 0))
    glow.putalpha(mask.filter(ImageFilter.GaussianBlur(22)).point(lambda v: int(v * 0.85)))
    shadow = Image.new('RGBA', (w, h), (2, 12, 30, 0))
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(6)).point(lambda v: int(v * 0.8)))
    shadow = ImageChops.offset(shadow, 0, 8)
    im = Image.alpha_composite(im, glow)
    im = Image.alpha_composite(im, shadow)
    fill = grad.copy(); fill.putalpha(mask)
    im = Image.alpha_composite(im, fill)
    # the thread: a thin luminous sine weaving under the title
    th = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    td = ImageDraw.Draw(th)
    pts = [(x, 300 + 16 * math.sin(x / 70.0) + 6 * math.sin(x / 23.0)) for x in range(120, w - 120, 4)]
    td.line(pts, fill=(120, 225, 255, 255), width=5)
    thg = th.filter(ImageFilter.GaussianBlur(7))
    im = Image.alpha_composite(im, thg)
    im = Image.alpha_composite(im, th)
    d = ImageDraw.Draw(im)
    f2 = ImageFont.truetype(F_BOLD, 54)
    sub = 'T H E   L A S T   B L U E'
    d.text((w // 2 + 2, 372 + 3), sub, font=f2, fill=(0, 10, 25, 170), anchor='mm')
    d.text((w // 2, 372), sub, font=f2, fill=(236, 246, 255, 255), anchor='mm')
    # (sous-titre arabe retiré à la demande de l'équipe : seul le titre anglais reste)
    return im


# ---------------------------------------------------------------- mattes and slides
def gradient_map(img, stops):
    g = ImageOps.grayscale(img)
    lut = []
    for ch in range(3):
        for v in range(256):
            t = v / 255.0
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]; t1, c1 = stops[i + 1]
                if t <= t1:
                    k = (t - t0) / max(1e-6, t1 - t0)
                    lut.append(int(c0[ch] + (c1[ch] - c0[ch]) * k)); break
            else:
                lut.append(stops[-1][1][ch])
    rgb = Image.merge('RGB', (g, g, g))
    return rgb.point(lut)


def vignette(img, strength=0.55):
    w, h = img.size
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).ellipse([-w * 0.15, -h * 0.25, w * 1.15, h * 1.25], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(min(w, h) // 6))
    dark = Image.new('RGB', (w, h), (0, 0, 0))
    return Image.composite(img, Image.blend(img, dark, strength), m)


def matte(src, grade, flip=False):
    im = Image.open(src).convert('RGB')
    im = im.crop((0, 0, im.width, int(im.height * 0.665)))
    if flip:
        im = ImageOps.mirror(im)
    im = Image.blend(im, Image.new('RGB', im.size, grade), 0.18)
    im = im.resize((2048, int(2048 * im.height / im.width)), Image.LANCZOS)
    a = Image.new('L', im.size, 255)
    ad = ImageDraw.Draw(a)
    h = im.height
    for y in range(int(h * 0.78), h):
        t = (y - h * 0.78) / (h * 0.22)
        ad.line([(0, y), (im.width, y)], fill=int(255 * (1 - t) ** 1.6))
    im = im.convert('RGBA'); im.putalpha(a)
    return im


coast = P + '/ui/coast_2060.jpg'
boy = P + '/ui/boy_reference.jpg'
bins = P + '/ui/bins_reference.jpg'

for name, fn in [('bin_paper', icon_paper), ('bin_textile', icon_textile), ('bin_pet', icon_pet),
                 ('bin_residual', icon_residual), ('bin_special', icon_special)]:
    fn().save(f'{P}/icons/{name}.png')
heart(True).save(P + '/icons/heart.png')
heart(False).save(P + '/icons/heart_empty.png')
o2_icon().save(P + '/icons/o2.png')
star(True).save(P + '/icons/star.png')
star(False).save(P + '/icons/star_empty.png')
check_icon(True).save(P + '/icons/ok.png')
check_icon(False).save(P + '/icons/wrong.png')
dot().save(P + '/icons/dot.png')
glow_sprite().save(P + '/icons/glow.png')
smoke_sprite().save(P + '/icons/smoke.png')
logo().save(P + '/ui/logo.png')

matte(coast, (150, 90, 40)).save(P + '/ui/matte_gabes.png')
matte(coast, (90, 70, 120), flip=True).save(P + '/ui/matte_skhira.png')
matte(coast, (160, 140, 70)).save(P + '/ui/matte_sidi.png')

# boy portrait (face crop, round)
b = Image.open(boy).convert('RGB').crop((250, 30, 470, 250)).resize((256, 256), Image.LANCZOS)
m = Image.new('L', (256 * S, 256 * S), 0)
ImageDraw.Draw(m).ellipse([0, 0, 256 * S - 1, 256 * S - 1], fill=255)
b = b.convert('RGBA'); b.putalpha(m.resize((256, 256), Image.LANCZOS))
b.save(P + '/ui/boy_portrait.png')

# intro slides (1600x900)
def fit(img, w=1600, h=900, focus=(0.5, 0.5)):
    r = max(w / img.width, h / img.height)
    img = img.resize((int(img.width * r) + 1, int(img.height * r) + 1), Image.LANCZOS)
    x = int((img.width - w) * focus[0]); y = int((img.height - h) * focus[1])
    return img.crop((x, y, x + w, y + h))

c = Image.open(coast).convert('RGB')
memory = gradient_map(c, [(0, (8, 26, 52)), (0.35, (30, 96, 150)), (0.7, (110, 196, 226)), (1, (244, 250, 252))])
memory = ImageEnhance.Contrast(memory).enhance(1.1)
vignette(fit(memory), 0.5).save(P + '/intro/slide_01.jpg', quality=88)
vignette(fit(c), 0.35).save(P + '/intro/slide_02.jpg', quality=88)
bo = Image.open('/home/claude/ref/CHARACTER_REFERENCE_Le_gardien.png').convert('RGB')
vignette(fit(bo, focus=(0.5, 0.18)), 0.35).save(P + '/intro/slide_03.jpg', quality=88)
bi = Image.open('/home/claude/ref/BINS_REFERENCE_Five_bins.jpg').convert('RGB')
# hide the reference watermark title (top-left) by cropping it out
bw, bh = bi.size
bi = bi.crop((int(bw * 0.06), int(bh * 0.12), bw, bh))
vignette(fit(bi, focus=(0.5, 0.6)), 0.3).save(P + '/intro/slide_04.jpg', quality=88)
warm = ImageEnhance.Color(fit(c, focus=(0.15, 0.5))).enhance(0.55)
warm = Image.blend(warm, gradient_map(fit(c, focus=(0.15, 0.5)), [(0, (10, 20, 40)), (0.6, (60, 140, 190)), (1, (255, 236, 200))]), 0.45)
vignette(warm, 0.45).save(P + '/intro/slide_05.jpg', quality=88)
# menu background: blurred + darkened coast for readable UI
mb = fit(c, 1920, 1080).filter(ImageFilter.GaussianBlur(1.2))
vignette(ImageEnhance.Brightness(mb).enhance(0.82), 0.55).save(P + '/ui/menu_bg.jpg', quality=86)
fit(memory, 1920, 1080).save(P + '/ui/memory_bg.jpg', quality=86)
print('ok')

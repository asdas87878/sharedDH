"""Chomp and smash pop-ups, options sheet 2: text only (T1-T4) and text + icon (I1-I4).

Mock-ups only, nothing here is in the game. Painted on the same 2x crops of the game's screenshots as sheet 1
(docs/attachments/archetypes-bite-frenzy.jpg, archetypes-smash.jpg), with Hugo's picked icons (Predator B,
Frenzy C, Breaker B, cut from docs/attachments/archetype-icons-draft-1.png) under the ring as on sheet 1.

    python tools/art/chomp_smash_options2.py
writes docs/attachments/chomp-smash-options-2-text.png and chomp-smash-options-2-icon.png.
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
A = os.path.join(ROOT, 'docs', 'attachments') + os.sep
CAPFONT = os.path.expanduser('~/.local/share/fonts/rice/snowfall/Nunito[wght].ttf')
# the game's font (Kit.Font = Enum.Font.FredokaOne), Roblox's own copy
GAMEFONT = os.path.expanduser(
	'~/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/version-63eb6055af4e4688/content/fonts/FredokaOne-Regular.ttf'
)
RED, ORANGE, YELLOW = (255, 96, 100), (255, 150, 50), (255, 205, 70)
DARK = (27, 31, 46)
AIR = (86, 190, 242)
WHITE = (255, 255, 255)


def cfont(size, weight='Black'):
	f = ImageFont.truetype(CAPFONT, size)
	try:
		f.set_variation_by_name(weight)
	except Exception:
		pass
	return f


def gfont(size):
	return ImageFont.truetype(GAMEFONT, size)


def ctext(img, xy, s, size, fill, anchor='mm', stroke=None, weight='Black'):
	d = ImageDraw.Draw(img)
	sw = stroke if stroke is not None else max(2, round(size / 9))
	d.text(xy, s, font=cfont(size, weight), fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=DARK)


def gtext(img, xy, s, size, fill, anchor='mm', stroke=None, angle=0):
	"""Game-font text with one dark outline; optional tilt."""
	sw = stroke if stroke is not None else max(3, round(size / 8))
	f = gfont(size)
	if not angle:
		ImageDraw.Draw(img).text(xy, s, font=f, fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=DARK)
		return
	tmp = Image.new('RGBA', (int(size * len(s) * 1.2 + 4 * sw + 40), int(size * 2 + 4 * sw)), (0, 0, 0, 0))
	ImageDraw.Draw(tmp).text((tmp.width / 2, tmp.height / 2), s, font=f, fill=fill, anchor='mm', stroke_width=sw,
		stroke_fill=DARK)
	tmp = tmp.rotate(angle, Image.BICUBIC, expand=True)
	img.alpha_composite(tmp, (round(xy[0] - tmp.width / 2), round(xy[1] - tmp.height / 2)))


def glen(s, size):
	return gfont(size).getlength(s)


# ---- icons from the draft sheet (as sheet 1 cut them)
def cut_icon(cx, cy):
	d = Image.open(A + 'archetype-icons-draft-1.png').convert('RGB')
	c = d.crop((cx - 72, cy - 72, cx + 72, cy + 72)).resize((288, 288), Image.LANCZOS)
	m = Image.new('L', c.size, 0)
	px, mp = c.load(), m.load()
	for y in range(c.height):
		for x in range(c.width):
			mp[x, y] = 255 if max(px[x, y]) > 75 else 0
	ImageDraw.floodfill(m, (0, 0), 128)
	for corner in [(c.width - 1, 0), (0, c.height - 1), (c.width - 1, c.height - 1)]:
		if m.getpixel(corner) == 0:
			ImageDraw.floodfill(m, corner, 128)
	alpha = m.point(lambda v: 0 if v == 128 else 255)
	out = Image.new('RGBA', c.size, DARK + (0,))
	body = c.copy()
	bp = body.load()
	for y in range(c.height):
		for x in range(c.width):
			if max(bp[x, y]) <= 75:
				bp[x, y] = DARK
	ring = alpha.filter(ImageFilter.MaxFilter(9))
	out.paste(Image.new('RGBA', c.size, DARK + (255,)), (0, 0), ring)
	out.paste(body, (0, 0), alpha.filter(ImageFilter.GaussianBlur(0.6)))
	return out.crop(ring.getbbox())


ICON = {'pred': cut_icon(910, 300), 'fren': cut_icon(1172, 460), 'brk': cut_icon(910, 615)}


def icon_w(key, h):
	ic = ICON[key]
	return ic.width * h / ic.height


def put(img, key, cx, cy, h, rot=0):
	ic = ICON[key]
	ic = ic.resize((round(ic.width * h / ic.height), h), Image.LANCZOS)
	if rot:
		ic = ic.rotate(rot, Image.BICUBIC, expand=True)
	img.alpha_composite(ic, (round(cx - ic.width / 2), round(cy - ic.height / 2)))


def bubble(img, cx, cy, r):
	d = ImageDraw.Draw(img)
	d.ellipse((cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2), fill=DARK)
	d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=AIR)
	d.ellipse((cx - r * 0.55, cy - r * 0.6, cx - r * 0.1, cy - r * 0.15), fill=WHITE)


def tag(img, cx, cy, s, colour, size, radius=None, pad=0.55, textcol=WHITE, outline=4, lpad=0):
	"""A flat tag: one fill, one dark outline, white game-font text. Returns its box."""
	d = ImageDraw.Draw(img)
	w = glen(s, size) + size * pad * 2 + lpad
	h = size * 1.3
	box = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
	cx = cx + lpad / 2
	d.rounded_rectangle(box, radius=radius if radius is not None else h / 2, fill=colour, outline=DARK, width=outline)
	d.text((cx, cy + size * 0.04), s, font=gfont(size), fill=textcol, anchor='mm', stroke_width=max(2, size // 12),
		stroke_fill=DARK)
	return box


def chevrons(img, cx, cy, n, size, colour=ORANGE):
	d = ImageDraw.Draw(img)
	for i in range(n):
		y = cy + (n - 1) / 2 * size * 0.5 - i * size * 0.5
		w, h, t = size, size * 0.42, size * 0.3
		pts = [(cx - w / 2, y + h / 2), (cx, y - h / 2), (cx + w / 2, y + h / 2), (cx + w / 2, y + h / 2 + t),
			(cx, y - h / 2 + t), (cx - w / 2, y + h / 2 + t)]
		d.polygon(pts, fill=colour, outline=DARK, width=3)


def inline(img, cx, cy, parts, size, fill, icon_h=None):
	"""A word with an icon in it: parts are strings or ('icon', key). Centred on (cx, cy)."""
	icon_h = icon_h or round(size * 1.05)
	gap = size * 0.04
	ws = [glen(p, size) if isinstance(p, str) else icon_w(p[1], icon_h) + 2 * gap for p in parts]
	x = cx - sum(ws) / 2
	for p, w in zip(parts, ws):
		if isinstance(p, str):
			gtext(img, (x, cy), p, size, fill, anchor='lm')
		else:
			put(img, p[1], x + w / 2, cy - size * 0.02, icon_h)
		x += w
	return cx - sum(ws) / 2, cx + sum(ws) / 2


def frenzy_colour(st):
	return RED if st < 2 else ORANGE


# ---- base crops (as sheet 1): the old words taken out, the ring's label shown as icons
def clone(img, box, dx, dy, keep=None):
	src = img.crop((box[0] + dx, box[1] + dy, box[2] + dx, box[3] + dy))
	if keep:
		m = Image.new('L', src.size, 255)
		dp, mp = img.crop(box).load(), m.load()
		for y in range(src.height):
			for x in range(src.width):
				if keep(dp[x, y]):
					mp[x, y] = 0
		img.paste(src, box[:2], m)
	else:
		img.paste(src, box[:2])


def pinkcoral(p):
	r, g, b = p[:3]
	return r > 180 and b > 150 and g < 170


bite0 = Image.open(A + 'archetypes-bite-frenzy.jpg').convert('RGB').crop((520, 200, 1000, 460)).resize((960, 520),
	Image.LANCZOS)
smash0 = Image.open(A + 'archetypes-smash.jpg').convert('RGB').crop((600, 220, 1080, 480)).resize((960, 520),
	Image.LANCZOS)
bite = bite0.copy()
clone(bite, (150, 120, 318, 186), 0, -90)
clone(bite, (348, 126, 512, 190), -168, 0, keep=pinkcoral)
clone(bite, (600, 342, 846, 380), 0, 44)
clone(bite, (296, 134, 400, 162), -84, 0)
clone(bite, (466, 132, 520, 164), -168, 0, keep=pinkcoral)
smash = smash0.copy()
clone(smash, (234, 124, 360, 184), 0, -56)
clone(smash, (534, 372, 654, 404), 0, 40)

BR = (722, 266)  # bite: air ring centre
SR = (592, 293)  # smash: air ring centre
RIDER_B = (200, 150)  # bite: the pop-up spot by the rider (where "Now" shows it)
RIDER_S = (240, 170)
HEAD_B = (530, 165)  # bite: by the ridden fish's head (right of its nameplate)
PROP_S = (440, 140)  # smash: the coral that breaks


def base(kind):
	img = (bite if kind == 'b' else smash).copy().convert('RGBA')
	if kind == 'b':
		put(img, 'pred', BR[0] - 22, BR[1] + 96, 36)
		put(img, 'fren', BR[0] + 22, BR[1] + 96, 36)
	else:
		put(img, 'brk', SR[0], SR[1] + 94, 36)
	return img


# ======== TEXT ONLY ========
# T1  the gain only: "+10% AIR", a "x2" counter that grows
def t1_chomp(img, st, x=None, y=None, k=1.0):
	x, y = (x, y) if x else (RIDER_B[0] - 30, RIDER_B[1] + 22)
	s = round(54 * k)
	gtext(img, (x, y), '+10% AIR', s, RED)
	if st >= 2:
		gtext(img, (x + glen('+10% AIR', s) / 2 + (14 + 8 * st) * k, y - 22 * k), f'x{st}', round((30 + 8 * st) * k),
			ORANGE, anchor='lm', angle=0)


def t1_smash(img, x=None, y=None):
	x, y = (x, y) if x else RIDER_S
	gtext(img, (x, y), '+4% AIR', 54, YELLOW)


# T2  word + gain on one flat tag
def t2_chomp(img, st, x=None, y=None, k=1.0):
	x, y = (x, y) if x else RIDER_B
	s = round(36 * k)
	if st < 2:
		tag(img, x, y, 'CHOMP!  +10%', RED, s, radius=8 * k)
	else:
		tag(img, x, y, f'FRENZY x{st}  +10%', ORANGE, s, radius=8 * k)


def t2_smash(img, x=None, y=None):
	x, y = (x, y) if x else RIDER_S
	tag(img, x, y, 'SMASH!  +4%', YELLOW, 36, radius=8, textcol=WHITE)


# T3  a big word at the action, growing with the chain
def t3_chomp(img, st, x=None, y=None, k=1.0):
	x, y = (x, y) if x else HEAD_B
	word = 'CHOMP' + '!' * st
	s = round((52 + 12 * (st - 1)) * k)
	gtext(img, (x, y), word, s, frenzy_colour(st), angle=6)
	gtext(img, (x + 6 * k, y + s * 0.72), '+10% air', round(28 * k), WHITE)


def t3_smash(img, x=None, y=None):
	x, y = (x, y) if x else PROP_S
	# letters knocked loose: each tilted and dropped a little
	s = 64
	letters = 'SMASH!'
	ws = [glen(c, s) for c in letters]
	cx = x - sum(ws) / 2
	jit = [(-10, -4), (8, 6), (-6, -8), (12, 4), (-8, 10), (14, -2)]
	for c, w, (a, dy) in zip(letters, ws, jit):
		gtext(img, (cx + w / 2, y + dy), c, s, YELLOW, angle=a)
		cx += w
	gtext(img, (x, y + 54), '+4% air', 26, WHITE)


# T4  at the air ring: just above it, the gain big, the word small above
def t4_chomp(img, st, ring=None, k=1.0):
	rx, ry = ring if ring else BR
	gtext(img, (rx, ry - 132 * k), 'CHOMP' if st < 2 else 'FRENZY', round(28 * k), frenzy_colour(st))
	gtext(img, (rx, ry - 96 * k), '+10%', round(46 * k), WHITE)
	if st >= 2:
		tag(img, rx + glen('+10%', round(46 * k)) / 2 + 34 * k, ry - 98 * k, f'x{st}', ORANGE, round(28 * k), pad=0.4)


def t4_smash(img):
	gtext(img, (SR[0], SR[1] - 136), 'SMASH', 28, YELLOW)
	gtext(img, (SR[0], SR[1] - 100), '+4%', 46, WHITE)


# ======== TEXT + ICON ========
# I1  icon left of the word, gain under the word
def i1_chomp(img, st, x=None, y=None, k=1.0):
	x, y = (x, y) if x else (RIDER_B[0] + 20, RIDER_B[1] + 6)
	word = 'CHOMP!' if st < 2 else f'FRENZY x{st}'
	s = round(42 * k)
	w = glen(word, s)
	put(img, 'pred', x - w / 2 - 44 * k, y + 4 * k, round(76 * k))
	gtext(img, (x, y - 10 * k), word, s, frenzy_colour(st))
	gtext(img, (x, y + 28 * k), '+10% air', round(24 * k), WHITE)


def i1_smash(img, x=None, y=None):
	x, y = (x, y) if x else (RIDER_S[0] + 20, RIDER_S[1] + 6)
	w = glen('SMASH!', 42)
	put(img, 'brk', x - w / 2 - 50, y + 4, 70)
	gtext(img, (x, y - 10), 'SMASH!', 42, YELLOW)
	gtext(img, (x, y + 28), '+4% air', 24, WHITE)


# I2  a pill with the icon as a round badge on its left end; Frenzy a second badge on the right
def badge(img, cx, cy, r, key, colour):
	d = ImageDraw.Draw(img)
	d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=colour, outline=DARK, width=4)
	put(img, key, cx, cy, round(r * 1.45))


def i2_chomp(img, st, x=None, y=None, k=1.0):
	x, y = (x, y) if x else (RIDER_B[0] - 10, RIDER_B[1] + 34)
	box = tag(img, x, y, 'CHOMP!  +10%', RED, round(32 * k), pad=0.55, lpad=40 * k)
	badge(img, box[0] + 2 * k, y, 34 * k, 'pred', WHITE)
	if st >= 2:
		bx = box[2] + 4 * k
		badge(img, bx, y - 4 * k, 30 * k, 'fren', WHITE)
		tag(img, bx + 16 * k, y + 26 * k, f'x{st}', ORANGE, round(20 * k), pad=0.35, outline=3)


def i2_smash(img, x=None, y=None):
	x, y = (x, y) if x else (RIDER_S[0] + 10, RIDER_S[1])
	box = tag(img, x, y, 'SMASH!  +4%', YELLOW, 32, pad=0.55, lpad=40)
	badge(img, box[0] + 2, y, 34, 'brk', WHITE)


# I3  icon above the number, at the action (over the fish's head / on the prop)
def i3_chomp(img, st, x=None, y=None, k=1.0):
	x, y = (x, y) if x else (HEAD_B[0] - 50, HEAD_B[1] - 20)
	h = round((70 + 8 * (st - 1)) * k)
	put(img, 'pred', x, y - 10 * k, h)
	gtext(img, (x, y + h * 0.5 + 18 * k), '+10%', round(38 * k), frenzy_colour(st))
	if st >= 2:
		chevrons(img, x + h * 0.75, y - 20 * k, st, 34 * k)


def i3_smash(img, x=None, y=None):
	x, y = (x, y) if x else (PROP_S[0], PROP_S[1] - 20)
	put(img, 'brk', x, y - 10, 70, rot=-8)
	gtext(img, (x, y + 52), '+4%', 38, YELLOW)


# I4  the icon takes a letter's place: CH(shark)MP / SMASH(fish)
def i4_chomp(img, st, x=None, y=None, k=1.0):
	x, y = (x, y) if x else (RIDER_B[0] - 10, RIDER_B[1] - 6)
	s = round(50 * k)
	l, r = inline(img, x, y, ['CH', ('icon', 'pred'), 'MP'], s, frenzy_colour(st), icon_h=round(s * 1.1))
	gtext(img, (x, y + 40 * k), '+10% air', round(24 * k), WHITE)
	if st >= 2:
		tag(img, r + 24 * k, y + 22 * k, f'x{st}', ORANGE, round(24 * k), pad=0.35, outline=3)


def i4_smash(img, x=None, y=None):
	x, y = (x, y) if x else (RIDER_S[0] + 20, RIDER_S[1] - 6)
	inline(img, x, y, ['SMASH', ('icon', 'brk')], 50, YELLOW, icon_h=56)
	gtext(img, (x, y + 40), '+4% air', 24, WHITE)


# ---- the 1st/2nd/3rd eat strip
def chain_strip(fn, w=960, h=150):
	strip = Image.new('RGBA', (w, h), (0, 0, 0, 0))
	strip.alpha_composite(bite0.crop((0, 400, 960, 520)).resize((w, h)).convert('RGBA'))
	strip.alpha_composite(Image.new('RGBA', (w, h), (20, 24, 38, 110)))
	for i, st in enumerate((1, 2, 3)):
		cx = w * (i + 0.5) / 3
		fn(strip, st, cx, h / 2 + 12)
		ctext(strip, (cx - w / 6 + 14, 18), ['1st eat', '2nd', '3rd'][i], 22, WHITE, anchor='lm', stroke=3)
	return strip


def strip_now(img, st, x, y):
	if st == 1:
		ctext(img, (x, y - 12), 'CHOMP!', 46, RED)
	else:
		ctext(img, (x, y - 12), f'FRENZY x{st}', 46, ORANGE)
	ctext(img, (x, y + 26), '+10% air', 24, WHITE)


def S(fn, k, dx=0, dy=0):
	return lambda img, st, x, y: fn(img, st, x + dx, y + dy, k=k)


def strip_t4(img, st, x, y):
	t4_chomp(img, st, ring=(x - 10, y + 120), k=0.95)


def tile(fn_b, st=2):
	img = base('b')
	fn_b(img, st)
	return img


def stile(fn):
	img = base('s')
	fn(img)
	return img


NOW_B = ('Now', bite0.copy().convert('RGBA'), chain_strip(strip_now),
	'"CHOMP!" (red), then "FRENZY x2/x3" (orange) by the rider, "+10% air" under it; 0.9 s, floats up.', 'As built')
NOW_S = ('Now', smash0.copy().convert('RGBA'), None,
	'"SMASH!" (yellow) by the rider, "+4% air" under it; 0.9 s, floats up. Small and easy to miss.', 'As built')

TEXT_B = [
	NOW_B,
	('T1  The gain only', tile(t1_chomp), chain_strip(S(t1_chomp, 0.7, -24)),
		'No word: "+10% AIR" big in red by the rider. Frenzy: an orange "x2", "x3" after it, bigger each eat.',
		'Small: the label text and size'),
	('T2  One flat tag', tile(t2_chomp), chain_strip(S(t2_chomp, 0.85)),
		'Word and gain on one line in a flat red tag ("CHOMP!  +10%"). Frenzy: the tag turns orange, "FRENZY x2  +10%".',
		'Small: a Frame + one label'),
	('T3  Big word by the head', tile(t3_chomp), chain_strip(S(t3_chomp, 0.62, 0, -16)),
		'A tilted word by the fish\'s head; each eat adds a "!", grows and turns red to orange. "+10% air" small under it.',
		'Small to medium: a BillboardGui on the fish'),
	('T4  Above the air ring', tile(t4_chomp), chain_strip(strip_t4),
		'Nothing by the rider: "+10%" just above the ring it fills, "CHOMP" small over it. Frenzy: "FRENZY" and an orange x2 chip.',
		'Small: a label anchored to the ring'),
]
TEXT_S = [
	NOW_S,
	('T1  The gain only', stile(t1_smash), None, '"+4% AIR" big in yellow by the rider, no word.',
		'Small: the label text and size'),
	('T2  One flat tag', stile(t2_smash), None, '"SMASH!  +4%" on one flat yellow tag by the rider, the same tag as the chomp.',
		'Small: a Frame + one label'),
	('T3  Big word at the prop', stile(t3_smash), None,
		'"SMASH!" on the breaking coral, its letters knocked loose (each tilted); "+4% air" under it.',
		'Medium: a BillboardGui at the prop'),
	('T4  Above the air ring', stile(t4_smash), None, '"+4%" just above the air ring, "SMASH" small over it. Nothing by the rider.',
		'Small: a label anchored to the ring'),
]
ICON_B = [
	NOW_B,
	('I1  Icon left of the word', tile(i1_chomp), chain_strip(S(i1_chomp, 0.8, 24, -8)),
		'Shark head, then "CHOMP!" with "+10% air" under. Frenzy: the word becomes "FRENZY x2" in orange, same icon.',
		'Small: today\'s pop-up + one image'),
	('I2  Pill with a badge', tile(i2_chomp), chain_strip(S(i2_chomp, 0.8, -4)),
		'A red pill "CHOMP!  +10%" with the icon in a round badge on its end. Frenzy: a second badge (chevrons) + x2.',
		'Small: a Frame, a label, one or two images'),
	('I3  Icon above the number', tile(i3_chomp), chain_strip(S(i3_chomp, 0.62, -20, -12)),
		'By the fish\'s head: the icon, "+10%" under it. Frenzy: number turns orange, the icon grows, chevrons stack.',
		'Small to medium: a BillboardGui on the fish'),
	('I4  Icon is a letter', tile(i4_chomp), chain_strip(S(i4_chomp, 0.75, -14, -10)),
		'"CH(shark)MP": the shark head is the O. Frenzy: the word goes orange with an x2 chip. "+10% air" under it.',
		'Small: three pieces in a row'),
]
ICON_S = [
	NOW_S,
	('I1  Icon left of the word', stile(i1_smash), None, 'The Breaker icon, then "SMASH!" with "+4% air" under it.',
		'Small: today\'s pop-up + one image'),
	('I2  Pill with a badge', stile(i2_smash), None, 'A yellow pill "SMASH!  +4%" with the Breaker icon in a round badge.',
		'Small: a Frame, a label, an image'),
	('I3  Icon above the number', stile(i3_smash), None, 'On the breaking coral: the icon, tilted, "+4%" under it.',
		'Medium: a BillboardGui at the prop'),
	('I4  Icon is a letter', stile(i4_smash), None, '"SMASH" with the Breaker fish in place of the "!"; "+4% air" under it.',
		'Small: two pieces in a row'),
]


# ---- the sheet (layout as sheet 1)
TW, TH = 600, 325
SH = 94
CAP = 118
PAD = 24
LEFT = 170
HEAD = 120
W = LEFT + 5 * TW + 6 * PAD
ROW_B = TH + SH + CAP + PAD
ROW_S = TH + CAP + PAD
H = HEAD + ROW_B + ROW_S + 70
BG = (16, 20, 32)


def wrap(s, f, w, d):
	out, line = [], ''
	for word in s.split():
		t = (line + ' ' + word).strip()
		if d.textlength(t, font=f) > w:
			out.append(line)
			line = word
		else:
			line = t
	out.append(line)
	return out


def row(sheet, items, y0, label, colour, sub, with_strip):
	d = ImageDraw.Draw(sheet)
	d.rounded_rectangle((PAD, y0, LEFT - 10, y0 + TH), radius=14, fill=colour)
	ctext(sheet, ((PAD + LEFT - 10) / 2, y0 + TH / 2 - 16), label, 32, WHITE, stroke=3)
	for i, ln in enumerate(sub):
		ctext(sheet, ((PAD + LEFT - 10) / 2, y0 + TH / 2 + 22 + i * 24), ln, 18, WHITE, stroke=2, weight='Bold')
	for i, (title, img, strip, cap, cost) in enumerate(items):
		x = LEFT + PAD + i * (TW + PAD)
		sheet.paste(img.convert('RGB').resize((TW, TH), Image.LANCZOS), (x, y0))
		d.rectangle((x - 1, y0 - 1, x + TW, y0 + TH), outline=WHITE if i == 0 else DARK, width=2)
		code = title.split()[0]
		tw = 64 if code == 'Now' else 52
		d.rounded_rectangle((x + 8, y0 + 8, x + 8 + tw, y0 + 46), radius=8, fill=DARK)
		ctext(sheet, (x + 8 + tw / 2, y0 + 27), code, 24, WHITE, stroke=0)
		y = y0 + TH
		if with_strip:
			sheet.paste(strip.convert('RGB').resize((TW, SH), Image.LANCZOS), (x, y + 4))
			y += SH + 4
		d.text((x, y + 10), title if code != 'Now' else 'Now (in the game)', font=cfont(22, 'Black'), fill=WHITE)
		fs = cfont(17, 'SemiBold')
		lines = wrap(cap, fs, TW, d)[:3]
		for j, ln in enumerate(lines):
			d.text((x, y + 40 + j * 21), ln, font=fs, fill=(200, 208, 225))
		d.text((x, y + 40 + len(lines) * 21 + 2), 'Build: ' + cost, font=cfont(17, 'ExtraBold'),
			fill=colour if cost != 'As built' else (150, 160, 180))


def sheet(title, sub, chomp, smashes, out):
	s = Image.new('RGBA', (W, H), BG + (255,))
	ctext(s, (PAD, 46), title, 42, WHITE, anchor='lm', stroke=0)
	ctext(s, (PAD, 92), sub, 22, (175, 185, 205), anchor='lm', stroke=0, weight='Bold')
	row(s, chomp, HEAD, 'CHOMP', RED, ['Predator eat', '+ Frenzy chain', '(tile: 2nd eat;', 'strip: 1st-3rd)'], True)
	row(s, smashes, HEAD + ROW_B, 'SMASH', (230, 170, 30), ['Breaker breaks', 'a prop'], False)
	ImageDraw.Draw(s).text((PAD, H - 44),
		'Pop-up text in the game\'s font (FredokaOne). Predator red #FF6064, Frenzy orange #FF9632, Breaker yellow '
		'#FFCD46; flat fills, one dark outline, no gradients. Icons under the ring as approved (being built). Draft 2, '
		'2026-11-13: nothing here is in the game.', font=cfont(19, 'Bold'), fill=(150, 160, 180))
	s.convert('RGB').save(out, optimize=True)
	print(out, s.size)


SUB = ('Mock-ups on the game\'s own screenshots (2x crop). Answer with one code per row, e.g. "CHOMP {a}, SMASH {b}" '
	'(mixing is fine).')
sheet('Chomp and smash, sheet 2a: TEXT ONLY', SUB.format(a='T2', b='T3'), TEXT_B, TEXT_S,
	A + 'chomp-smash-options-2-text.png')
sheet('Chomp and smash, sheet 2b: TEXT + ICON', SUB.format(a='I1', b='I4'), ICON_B, ICON_S,
	A + 'chomp-smash-options-2-icon.png')

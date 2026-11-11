// Pass 2 of the HUD mock-ups (2026-11-11, the user: get much closer to Ride a Dino's HUD and its overlays, gradients
// and textures; keep the riding loop's screen as it has it; a few variants: Brick, Bubble, a mix, bubble over brick).
// Loaded by mockups.html after its own script, and uses its scene, its fish and its helpers.
//   ?state=v2-<frame>&skin=brick|bubble|mix|over     frames: riding low hop tamed miss great dock auras pieces
window.onerror = (m, f, l, c, e) => { document.getElementById("root").innerHTML = '<pre id="err" style="color:#f66;font-size:14px;white-space:pre-wrap">' + (e && e.stack ? e.stack : m) + '</pre>'; };
(function () {
	if (!STATE.startsWith("v2-")) {
		return;
	}
	const FRAME = STATE.slice(3);
	const SPR = q.get("sprites") || "";
	const DESK = !TOUCH;
	const lighten = (c, t) => mix(c, [255, 255, 255], t);
	const darken = (c, t) => mix(c, [0, 0, 0], t);
	const rgba = (c, a) => `rgba(${c.map((v) => Math.round(v)).join(",")},${a})`;

	const LOOK = SKIN === "pick" ? "mix" : SKIN === "dino" ? "brick" : SKIN;
	const REF = SKIN === "dino"; // pass 3: built as the reference builds its own, piece by piece
	const TEXQ = q.get("tex") || (REF ? "bubble" : "stud"); // the pattern on a brick: stud, bubble, or dome (bubbles and the round shine)
	const TRAYS = SKIN === "over" || SKIN === "pick"; // glass round the land strip, the caught row and the panels
	const SK = {
		brick: { ink: [16, 36, 63], rad: 6, name: "A. Brick" },
		bubble: { ink: [8, 34, 78], rad: 16, name: "B. Bubble" },
		mix: { ink: [11, 47, 102], rad: 15, name: "C. Brick and Bubble" },
		over: { ink: [16, 36, 63], rad: 8, name: "D. Bubble over Brick" },
		pick: { ink: [11, 47, 102], rad: 15, name: "E. C, with glass on what holds things" },
		dino: { ink: [16, 36, 63], rad: 4, name: "Pass 3: A's build, E's pattern" },
	}[SKIN];
	const INKC = rgb(SK.ink);
	const NAVY = [24, 52, 92], AQUA = [51, 214, 240], SUN = [255, 210, 63], CORAL = [255, 90, 95], LIME = [124, 224, 75],
		GREEN = [52, 168, 83], BLUE = [58, 130, 246], WHITE = [246, 249, 253], GREY = [150, 162, 178];

	const style = document.createElement("style");
	style.textContent = `
	.v2 { font-family: Fredoka; color: #fff; }
	.v2 .t { paint-order: stroke fill; -webkit-text-stroke: 3.5px ${INKC}; white-space: nowrap; line-height: 1.05; text-shadow: 0 1.5px 0 ${INKC}; }
	.v2 .t.thin { -webkit-text-stroke-width: 2.6px; text-shadow: 0 1px 0 ${INKC}; }
	.v2 .gt { display: inline-grid; white-space: nowrap; line-height: 1.05; }
	.v2 .gt > span { grid-area: 1 / 1; }
	.v2 .gt > .b { paint-order: stroke fill; -webkit-text-stroke: 3.5px ${INKC}; color: ${INKC}; text-shadow: 0 1.5px 0 ${INKC}; }
	.v2 .gt > .f { -webkit-background-clip: text; background-clip: text; -webkit-text-fill-color: transparent; }
	.v2 .pl { position: relative; box-sizing: border-box; }
	.v2 .ov { position: absolute; inset: 0; border-radius: inherit; overflow: hidden; pointer-events: none; }
	.v2 .ov > div { position: absolute; }
	.v2 .in { position: relative; }
	.v2 .rowx { display: flex; align-items: center; }
	.v2 .colx { display: flex; flex-direction: column; align-items: center; }
	.v2 img { display: block; object-fit: contain; }
	`;
	document.head.appendChild(style);

	// ---------------------------------------------------------------- the surface treatments (the "overlays")
	// Roblox: the stud pattern is one small tiling picture (the map's own stud picture can serve); the streak is a
	// turned frame inside a clipped group; the dome is a frame with a gradient that fades out.
	const texStud = (a = 1) => `<div style="inset:0;opacity:${a};background-image:radial-gradient(circle at 50% 44%, rgba(255,255,255,.23) 0 31%, rgba(0,0,0,.15) 32% 43%, transparent 44%);background-size:11px 11px;background-position:3px 2px"></div>`;
	const texBubbles = (a = 1) => `<div style="inset:0;opacity:${a};background-image:radial-gradient(circle at 22% 30%, transparent 0 2.2px, rgba(255,255,255,.34) 2.4px 3.3px, transparent 3.6px),radial-gradient(circle at 70% 64%, transparent 0 1.2px, rgba(255,255,255,.3) 1.4px 2.1px, transparent 2.4px),radial-gradient(circle at 48% 86%, rgba(255,255,255,.22) 0 1.1px, transparent 1.3px);background-size:41px 31px, 29px 37px, 23px 19px"></div>`;
	const glossStreak = `<div style="inset:0;background:linear-gradient(115deg, transparent 58%, rgba(255,255,255,.17) 58% 71%, transparent 71% 76%, rgba(255,255,255,.11) 76% 82%, transparent 82%)"></div>`;
	const glossDome = (r) => `<div style="left:3px;right:3px;top:2px;height:46%;border-radius:${Math.max(3, r - 3)}px ${Math.max(3, r - 3)}px ${r * 1.6}px ${r * 1.6}px / ${Math.max(3, r - 3)}px ${Math.max(3, r - 3)}px 70% 70%;background:linear-gradient(180deg, rgba(255,255,255,.5), rgba(255,255,255,.07))"></div>`;

	// One plate: every panel, chip, button and tile is this, in the variant's treatment
	function plate(c, inner, o = {}) {
		const r = o.r ?? SK.rad;
		const size = (o.w ? `width:${o.w}px;` : "") + (o.h ? `height:${o.h}px;` : "");
		const pad = o.pad ?? "3px 10px 4px";
		const body = `<div class="in" style="padding:${pad};${o.inner || ""}">${inner}</div>`;
		const brick = (extra, rr, lip) => {
			if (o.see) {
				// a see-through plate with a bright edge, as the reference builds its banner and its revive bar
				return `<div class="pl" style="background:${o.see[0]};border:3px solid ${o.see[1]};border-radius:${rr}px;${extra}">${body}</div>`;
			}
			const candy = LOOK === "mix";
			const out = candy ? rgb(darken(c, 0.58)) : INKC;
			const a = o.alpha ?? 1;
			const fade = o.fade && !candy;
			const bg = fade
				? `linear-gradient(90deg, ${rgba(c, 0.92 * a)}, ${rgba(c, 0.55 * a)} 55%, ${rgba(c, 0)})`
				: candy
					? `linear-gradient(180deg, ${rgba(lighten(c, 0.34), a)}, ${rgba(lighten(c, 0.06), a)} 46%, ${rgba(darken(c, 0.1), a)})`
					: `linear-gradient(180deg, ${rgba(lighten(c, 0.14), a)}, ${rgba(c, a)} 50%, ${rgba(darken(c, 0.15), a)})`;
			const border = fade ? `border-left:3px solid ${out};border-bottom:3px solid ${out};` : `border:3px solid ${out};`;
			const shadow = (lip && !fade ? `0 4px 0 ${out}` : "") + (candy ? `${lip ? "," : ""}inset 0 0 0 1.5px rgba(255,255,255,.34)` : "");
			const mask = fade ? "-webkit-mask-image:linear-gradient(90deg,#000 20%,transparent 85%);" : "";
			const ov = (o.tex === false ? "" : candy || TEXQ !== "stud" ? texBubbles(0.9) : texStud(1)) + (o.gloss === false || fade ? "" : candy || TEXQ === "dome" ? glossDome(rr) : glossStreak);
			return `<div class="pl" style="background:${bg};${border}border-radius:${fade ? `${rr}px 0 0 ${rr}px` : rr + "px"};${shadow ? `box-shadow:${shadow};` : ""}${extra}"><div class="ov" style="${mask}">${ov}</div>${body}</div>`;
		};
		const glass = (extra, rr, tint, innerHtml, solid) => {
			const hi = solid ? 0.9 : 0.6, lo = solid ? 0.88 : 0.5;
			const bg = `linear-gradient(180deg, ${rgba(lighten(tint, 0.12), hi)}, ${rgba(darken(tint, 0.38), lo)})`;
			const border = "border:2px solid rgba(255,255,255,.88);";
			const ov = (o.tex === false ? "" : texBubbles()) + (o.gloss === false ? "" : glossDome(rr));
			return `<div class="pl" style="background:${bg};${border}border-radius:${rr}px;box-shadow:0 0 0 1.5px rgba(4,30,70,.5), inset 0 0 0 2px rgba(255,255,255,.14);${extra}"><div class="ov">${ov}</div>${innerHtml}</div>`;
		};
		const extra = size + (o.style || "");
		if (SKIN === "pick" && o.shell) {
			return glass(extra + "padding:4px;", r + 8, [90, 170, 240], brick("", r, false), false);
		}
		if (LOOK === "brick" || LOOK === "mix") {
			return brick(extra, r, o.lip !== false);
		}
		if (LOOK === "bubble") {
			return glass(extra, o.r ?? (o.pill === false ? 12 : SK.rad), c, body, o.solid);
		}
		// bubble over brick: the big pieces are a glass shell holding a brick; the small ones are plain bricks
		if (!o.major) {
			return brick(extra, r, o.lip !== false);
		}
		const core = brick(o.w ? "width:100%;height:100%;" : "", o.r === 999 ? 999 : Math.max(4, r), false);
		return glass(extra + "padding:4px;", o.r === 999 ? 999 : r + 8, [90, 170, 240], core, false);
	}

	const T = (text, size, colour = "#fff", cls = "") => `<span class="t ${cls}" style="font-size:${size}px;color:${colour}">${text}</span>`;
	// text filled with a gradient, like the reference's rarity words (Roblox: a gradient on the label, a stroke under it)
	const GT = (text, size, c1, c2) => `<span class="gt" style="font-size:${size}px"><span class="b">${text}</span><span class="f" style="background-image:linear-gradient(180deg, ${rgb(c1)}, ${rgb(c2)})">${text}</span></span>`;
	const tierText = (tier, size) => {
		const c = tier === "Secret" ? [70, 70, 86] : TIER[tier];
		return GT(tier, size, lighten(c, 0.45), c);
	};
	const thumb = (name, w, h) => `<img src="${SPR}/${name}.png" style="width:${w}px;height:${h || w}px">`;

	// ---------------------------------------------------------------- icons (small pictures in the game: drawn by code)
	const svg = (w, h, body, vb) => `<svg width="${w}" height="${h}" viewBox="${vb || `0 0 ${w} ${h}`}" style="display:block;overflow:visible">${body}</svg>`;
	const icBubble = (d) => svg(d, d, `<circle cx="12" cy="12" r="9.6" fill="#7fe3ff" stroke="${INKC}" stroke-width="2.6"/><circle cx="12" cy="12" r="6.4" fill="none" stroke="#c9f5ff" stroke-width="2"/><ellipse cx="8.6" cy="8" rx="2.5" ry="1.7" fill="#fff" transform="rotate(-35 8.6 8)"/>`, "0 0 24 24");
	const icCoin = (d) => svg(d, d, `<circle cx="12" cy="13" r="9.6" fill="#c8870a" stroke="${INKC}" stroke-width="2.6"/><circle cx="12" cy="11" r="9.6" fill="#ffd23f" stroke="${INKC}" stroke-width="2.6"/><circle cx="12" cy="11" r="5.6" fill="none" stroke="#f0a818" stroke-width="2.2"/><ellipse cx="8.2" cy="7.2" rx="2.4" ry="1.5" fill="#fff6c8" transform="rotate(-35 8.2 7.2)"/>`, "0 0 24 24");
	const icArrow = (d, colour, down, outline) => svg(d, d, `<g transform="${down ? "rotate(180 12 12)" : ""}"><path d="M12 2.5 L21.5 12.5 H16 V17 H8 V12.5 H2.5 Z" fill="${colour}" stroke="${outline || "none"}" stroke-width="2.2" stroke-linejoin="round"/><rect x="8" y="19" width="8" height="3" rx="1.2" fill="${colour}" stroke="${outline || "none"}" stroke-width="2.2"/></g>`, "0 0 24 24");
	const icHeart = (d) => svg(d, d, `<path d="M12 21 C4 15 2 11 2 7.5 C2 4.5 4.4 2.5 7 2.5 C9 2.5 11 3.6 12 5.6 C13 3.6 15 2.5 17 2.5 C19.6 2.5 22 4.5 22 7.5 C22 11 20 15 12 21 Z" fill="#ff4f7b" stroke="${INKC}" stroke-width="2.4" stroke-linejoin="round"/><ellipse cx="7.6" cy="7" rx="2.6" ry="1.6" fill="#ffc2d2" transform="rotate(-30 7.6 7)"/>`, "0 0 24 24");
	const icFish = (w, colour) => svg(w, w * 0.66, `<path d="M21 4 L29 1.5 L27.5 8 L29 14.5 L21 12 Z" fill="${colour}" stroke="${INKC}" stroke-width="2.2" stroke-linejoin="round"/><rect x="1.5" y="1.5" width="21" height="13" rx="6.5" fill="${colour}" stroke="${INKC}" stroke-width="2.2"/><circle cx="7" cy="6.6" r="1.7" fill="${INKC}"/>`, "0 0 30 16");
	const icBag = (d) => svg(d, d, `<path d="M8 10 V7.5 A4 4 0 0 1 16 7.5 V10" fill="none" stroke="${INKC}" stroke-width="5"/><path d="M8 10 V7.5 A4 4 0 0 1 16 7.5 V10" fill="none" stroke="#dfe7f2" stroke-width="2"/><path d="M3.5 9 H20.5 L18.6 21 H5.4 Z" fill="#ff5a6e" stroke="${INKC}" stroke-width="2.4" stroke-linejoin="round"/><path d="M5 11 H19 L18.6 13.4 H5.4 Z" fill="#ff9aa6"/>`, "0 0 24 24");
	const icBook = (d) => svg(d, d, `<path d="M4 4.5 H18 A2 2 0 0 1 20 6.5 V21 H6 A2 2 0 0 1 4 19 Z" fill="#3a82f6" stroke="${INKC}" stroke-width="2.4" stroke-linejoin="round"/><path d="M6 17.2 H20 V21 H6 A1.9 1.9 0 0 1 6 17.2 Z" fill="#eef4ff" stroke="${INKC}" stroke-width="2"/><rect x="8" y="7.4" width="8" height="2.4" rx="1" fill="#bcd6ff"/><path d="M14 17.5 V23 L15.6 21.6 L17.2 23 V17.5 Z" fill="#ff5a6e" stroke="${INKC}" stroke-width="1.2"/>`, "0 0 24 24");
	const icFlag = (d) => svg(d, d, `<rect x="5" y="3" width="2.6" height="19" rx="1" fill="#fff" stroke="${INKC}" stroke-width="1.6"/><path d="M7.6 4 L20 7.5 L7.6 12 Z" fill="#ffd23f" stroke="${INKC}" stroke-width="1.8" stroke-linejoin="round"/>`, "0 0 24 24");

	// ---------------------------------------------------------------- the pieces of the riding screen
	const SHORT = ["Shallows", "Reef", "Kelp", "Wrecks", "Blue", "Twilight", "Midnight", "Vents", "Bones", "Under"];
	// The strip of the ten lands across the top (the reference's place and job), stepping down land by land (ours)
	function landStrip(landIndex, u, metres, best) {
		const tw = DESK ? 30 : 28, gap = 3, step = REF ? 0 : 1.6;
		let s = "";
		const x0 = -(10 * tw + 9 * gap) / 2;
		for (let i = 0; i < 10; i++) {
			const c = LANDS[i][1];
			const on = i === landIndex;
			const label = DESK ? `<div class="t thin" style="position:absolute;left:50%;top:1px;transform:translateX(-50%);font-size:${SHORT[i].length > 6 ? 5.6 : 6.6}px">${SHORT[i]}</div>` : `<div class="t thin" style="position:absolute;left:50%;top:50%;transform:translate(-50%,-52%);font-size:11px;opacity:${i <= landIndex ? 1 : 0.75}">${i + 1}</div>`;
			// a small picture of the land in the game; here its colour, a horizon and a block or two
			const art = `<div style="position:absolute;left:0;right:0;bottom:0;height:42%;background:${rgb(darken(c, 0.18))}"></div><div style="position:absolute;left:14%;bottom:30%;width:22%;height:${DESK ? 30 : 24}%;background:${rgb(darken(c, 0.34))};border-radius:1px"></div><div style="position:absolute;right:16%;bottom:34%;width:16%;height:${DESK ? 20 : 16}%;background:${rgb(lighten(c, 0.3))};border-radius:1px"></div>`;
			s += `<div style="left:${x0 + i * (tw + gap)}px;top:${i * step}px">${plate(i > landIndex ? mix(c, [40, 60, 96], 0.45) : c, art + label, { w: tw, h: tw, pad: "0", r: REF ? 3 : LOOK === "bubble" ? 8 : LOOK === "mix" ? 7 : 5, lip: false, gloss: LOOK !== "brick" && LOOK !== "over", tex: false, inner: "position:absolute;inset:0;overflow:hidden;border-radius:inherit", style: on ? `outline:2.5px solid #fff;outline-offset:1px;` : i > landIndex ? "opacity:.86;" : "" })}</div>`;
		}
		if (TRAYS) {
			const w = 10 * tw + 9 * gap;
			s = `<div style="left:${x0 - 7}px;top:-6px;width:${w + 14}px;height:${tw + 12}px;box-sizing:border-box;border-radius:12px;transform:rotate(${Math.atan((9 * step) / w) * 180 / Math.PI}deg);transform-origin:0 50%;background:linear-gradient(180deg, rgba(120,200,255,.4), rgba(10,50,110,.5));border:2px solid rgba(255,255,255,.88);box-shadow:0 0 0 1.5px rgba(4,30,70,.5)"><div style="position:absolute;left:6px;right:6px;top:2px;height:40%;border-radius:9px 9px 60% 60%;background:linear-gradient(180deg, rgba(255,255,255,.45), rgba(255,255,255,0))"></div></div>` + s;
		}
		const mx = x0 + landIndex * (tw + gap) + u * tw, my = landIndex * step + tw;
		// you: a round badge on the strip's lower edge, and the metres under it
		s += `<div style="left:${mx - 9}px;top:${my - 7}px;width:18px;height:18px;border-radius:50%;box-sizing:border-box;background:#3d8bf0;border:2.5px solid #fff;box-shadow:0 0 0 2px ${INKC}"><div style="position:absolute;left:3.5px;top:1.5px;width:6px;height:6px;border-radius:2px;background:#f2c9a0"></div></div>`;
		s += `<div style="left:${mx}px;top:${my + 15}px;transform:translateX(-50%)">${plate(NAVY, `<div class="rowx" style="gap:5px">${T(LANDS[landIndex][0].toUpperCase(), 9.5, rgb(lighten(LANDS[landIndex][1], 0.35)), "thin")}${T(metres + " m", 12.5)}</div>`, { pad: "1px 8px 2px", r: 999, lip: false, gloss: false, tex: false, alpha: 0.86 })}</div>`;
		if (best !== undefined) {
			const bx = x0 + best * (tw + gap), by = Math.floor(best) * step;
			s += `<div style="left:${bx - 1}px;top:${by - 3}px;width:2.5px;height:${tw + 6}px;background:#ffd23f;box-shadow:0 0 0 1.5px ${INKC}"></div>`;
			s += `<div style="left:${bx + 3}px;top:${by + tw + 1}px">${T(REF ? "BEST 310 m" : "BEST", 8, "#ffd23f", "thin")}</div>`;
		}
		return s;
	}

	// The two rings beside the rider: the time left on this fish (with the seconds, ours) and the tame
	function ringV2(d, thick, frac, c, inner, o = {}) {
		const deg = Math.max(0, Math.min(1, frac)) * 360;
		if (REF) {
			const end = Math.min(360, deg + (o.red && frac < 1 ? 16 : 0));
			const flat = `conic-gradient(${rgba(c, 0.95)} 0 ${deg}deg, rgba(255,70,80,.95) ${deg}deg ${end}deg, rgba(10,28,52,.5) ${end}deg 360deg)`;
			const h = d - thick * 2;
			return `<div style="position:relative;width:${d}px;height:${d}px;border-radius:50%;background:${flat};-webkit-mask:radial-gradient(circle, transparent ${h / 2 - 0.5}px, #000 ${h / 2}px)"></div>`
				+ `<div class="colx" style="position:absolute;left:${thick}px;top:${thick}px;width:${h}px;height:${h}px;border-radius:50%;justify-content:center;background:${o.fillHole ? "rgba(10,28,52,.5)" : "transparent"}">${inner}</div>`;
		}
		const spent = LOOK === "bubble" ? "rgba(255,255,255,.2)" : rgba(SK.ink, 0.72);
		const arc = `conic-gradient(${rgb(lighten(c, 0.12))} 0 ${deg}deg, ${o.red && frac < 1 ? "rgba(255,70,80,.9)" : spent} ${deg}deg ${Math.min(360, deg + (o.red ? 14 : 0))}deg, ${spent} ${Math.min(360, deg + (o.red ? 14 : 0))}deg 360deg)`;
		const hole = d - thick * 2;
		const border = LOOK === "bubble" ? "2px solid rgba(255,255,255,.9)" : `3px solid ${LOOK === "mix" ? rgb(darken(c, 0.62)) : INKC}`;
		const bw = LOOK === "bubble" ? 2 : 3;
		const holeBg = LOOK === "bubble" ? "rgba(8,34,78,.5)" : LOOK === "mix" ? rgb(darken(c, 0.72)) : rgb(NAVY);
		const gloss = LOOK === "brick" ? "" : `<div style="position:absolute;left:14%;top:5%;width:72%;height:42%;border-radius:50%;background:linear-gradient(180deg, rgba(255,255,255,.5), rgba(255,255,255,0))"></div>`;
		const studs = LOOK === "brick" || LOOK === "over" ? `<div style="position:absolute;inset:0;border-radius:50%;overflow:hidden">${texStud(0.9).replace("<div style=\"", "<div style=\"position:absolute;")}</div>` : "";
		let s = `<div style="position:relative;width:${d}px;height:${d}px;border-radius:50%;box-sizing:border-box;background:${arc};border:${border};${LOOK === "bubble" ? "box-shadow:0 0 0 1.5px rgba(4,30,70,.5);" : `box-shadow:0 3px 0 ${LOOK === "mix" ? rgb(darken(c, 0.62)) : INKC};`}">${studs}`
			+ `<div class="colx" style="position:absolute;left:${thick - bw}px;top:${thick - bw}px;width:${hole}px;height:${hole}px;border-radius:50%;box-sizing:border-box;background:${holeBg};border:${border};justify-content:center">${inner}</div>${gloss}</div>`;
		if (LOOK === "over" && o.major) {
			s = `<div style="position:relative;padding:4px;border-radius:50%;background:linear-gradient(180deg, rgba(120,200,255,.4), rgba(10,50,110,.5));border:2px solid rgba(255,255,255,.88);box-shadow:0 0 0 1.5px rgba(4,30,70,.5)">${s}<div style="position:absolute;left:16%;top:4%;width:68%;height:40%;border-radius:50%;background:linear-gradient(180deg, rgba(255,255,255,.5), rgba(255,255,255,0))"></div></div>`;
		}
		return s;
	}
	function rings(o) {
		const k = DESK ? 0.82 : 1;
		const c = o.frac < 0.34 ? CORAL : o.frac < 0.6 ? SUN : AQUA;
		const d = (o.low ? 72 : 64) * k;
		const num = `<div class="colx">${T(o.secs, (o.secs.length > 3 ? 17 : 21) * k * (o.low ? 1.1 : 1))}<div class="t thin" style="font-size:${7.5 * k}px;margin-top:-1px;opacity:.9">SEC</div></div>`;
		let s = `<div style="left:${40 * k}px;top:${-d / 2 - 6}px">${ringV2(d, (REF ? 14 : 11) * k, o.frac, c, num, { red: true, major: true, fillHole: true })}</div>`;
		const tc = TIER[o.tier];
		s += `<div style="left:0;top:${-2}px">${ringV2(34 * k, (REF ? 10.5 : 7.5) * k, o.tame, o.tame >= 1 ? LIME : REF ? [240, 96, 200] : tc, REF ? "" : icFish(13 * k, o.tame >= 1 ? "#c8ffb0" : "#fff"))}</div>`;
		if (o.name) {
			s += `<div class="colx" style="left:${40 * k + d / 2}px;top:${d / 2 - 1}px;transform:translateX(-50%)">${T(o.name, 12.5 * k)}<div style="margin-top:-2px">${tierText(o.tier, 10.5 * k)}</div></div>`;
		}
		return s;
	}

	// The jump button, where the reference has it: the arrow turns over in the air; the key's name under it on a keyboard
	function hopButton(mode, o = {}) {
		if (REF) {
			const dd = DESK ? 78 : 92;
			const ringC = o.hot ? "#ff5a5f" : mode === "grab" ? "rgba(130,232,255,.85)" : "rgba(255,255,255,.42)";
			const arrowC = mode === "off" ? "rgba(255,255,255,.35)" : o.hot ? "#ffd23f" : "rgba(238,246,255,.86)";
			let b = `<div class="colx" style="width:${dd}px;height:${dd}px;border-radius:50%;box-sizing:border-box;background:rgba(10,24,44,.5);border:${o.hot ? 4 : 3}px solid ${ringC};box-shadow:0 0 0 3px rgba(10,24,44,.3);justify-content:center">${icArrow(DESK ? 34 : 30, arrowC, mode === "grab")}${DESK ? "" : `<div style="font-size:15px;line-height:1;margin-top:3px;color:${arrowC}">${mode === "grab" ? "GRAB" : "HOP"}</div>`}</div>`;
			if (DESK) {
				b += `<div style="display:flex;justify-content:center;margin-top:-9px;position:relative"><div style="background:#fff;border:3px solid ${INKC};border-radius:8px;padding:2px 14px 3px;font-size:13px;line-height:1.1;color:${INKC}">Space</div></div>`;
			}
			return `<div style="right:0;bottom:0"><div style="position:relative">${b}</div></div>`;
		}
		const d = DESK ? 78 : 92;
		const c = mode === "grab" ? AQUA : mode === "off" ? GREY : SUN;
		const inkText = LOOK === "bubble" ? (mode === "grab" ? "#fff" : mode === "off" ? "#c9d6e6" : "#ffe066") : rgb(LOOK === "mix" ? darken(c, 0.7) : SK.ink);
		const face = `<div class="colx" style="justify-content:center;height:100%">${icArrow(DESK ? 28 : 30, inkText, mode === "grab")}${DESK ? "" : `<div style="font-size:18px;line-height:1;margin-top:3px;color:${inkText}">${mode === "grab" ? "GRAB" : "HOP"}</div>`}</div>`;
		let s = plate(LOOK === "bubble" ? (mode === "grab" ? [40, 190, 240] : mode === "off" ? [70, 90, 120] : [70, 150, 235]) : c, face, { w: d, h: d, r: 999, pad: "0", inner: "height:100%", major: true, style: o.hot ? "transform:scale(1.08);" : "" });
		if (o.hot) {
			s += `<div style="position:absolute;left:-8px;top:-8px;width:${d + 16}px;height:${d + 16}px;border-radius:50%;box-sizing:border-box;border:4px solid #ff5a5f"></div>`;
		}
		if (DESK) {
			s += `<div style="display:flex;justify-content:center;margin-top:${LOOK === "bubble" ? 5 : 7}px">${plate(WHITE, `<div style="font-size:12.5px;color:${INKC}">Space</div>`, { pad: "1px 12px 2px", r: 7, tex: false, gloss: false, solid: true, lip: SKIN !== "bubble" })}</div>`;
		}
		return `<div style="right:0;bottom:0"><div style="position:relative">${s}</div></div>`;
	}

	// The stat rows (the reference: bottom left): your Oxygen, your coins
	function statRow(icon, text, colour, plus) {
		const row = `<div class="rowx" style="gap:7px;height:100%">${icon}${T(text, 16, colour)}</div>`;
		const p = plus ? `<div style="position:absolute;left:${LOOK === "brick" ? 134 : LOOK === "over" ? 130 : 118}px;top:${LOOK === "over" ? 6 : 2}px">${plate(LIME, `<div style="font-size:17px;line-height:19px;color:#fff" class="t thin">+</div>`, { w: 25, h: 25, pad: "0", r: 5, inner: "text-align:center", lip: false, solid: true })}</div>` : "";
		return `<div style="position:relative;margin-bottom:5px">${plate(LOOK === "bubble" ? [20, 70, 130] : NAVY, row, { w: LOOK === "brick" ? 128 : 112, h: 29, pad: "0 0 0 8px", inner: "height:100%", fade: LOOK === "brick", major: true, alpha: LOOK === "brick" ? 0.9 : 1, r: LOOK === "brick" ? 6 : LOOK === "over" ? 7 : 999 })}${p}</div>`;
	}
	const stats = (oxygen, coins, o = {}) => (o.boost ? statRow(icCoin(17), `<span style="color:#9cf06a">x2</span> ${o.boost}`, "#fff") : "") + statRow(icBubble(20), oxygen, "#fff", o.plus) + statRow(icCoin(20), coins, "#ffe066", o.plus);

	// The slots at the bottom middle: what you carry home (the reference's row of seven)
	const TILE = { Common: [176, 184, 196], Uncommon: [98, 208, 98], Rare: [86, 150, 250], Epic: [176, 104, 250], Legendary: [255, 184, 52], Mythic: [250, 84, 104], Secret: [44, 44, 58] };
	function slot(item, size, sel) {
		if (!item) {
			return plate(LOOK === "bubble" ? [30, 80, 140] : [18, 40, 70], "", { w: size, h: size, pad: "0", r: REF ? 2 : 5, lip: false, gloss: false, alpha: REF ? 0.3 : 0.55, tex: LOOK !== "bubble" && !REF });
		}
		const [name, tier, tag] = item;
		const label = name.length > 7 ? name.slice(0, 6).trim() + "." : name;
		const inner = `<div style="position:absolute;inset:0">${thumb(name.replace(/ /g, ""), size - 8, size - 12)}</div>`
			+ (tag ? `<div class="t thin" style="position:absolute;left:2px;top:0;font-size:${size * 0.19}px;color:${tag === "GOLD" ? "#ffd23f" : tag === "BIG" ? "#ffb057" : "#dfe7f2"}">${tag}</div>` : "")
			+ `<div class="t thin" style="position:absolute;left:50%;bottom:0;transform:translateX(-50%);font-size:${size * 0.25}px">${label}</div>`;
		return plate(TILE[tier], inner, { w: size, h: size, pad: "0", r: REF ? 2 : 5, lip: false, tex: false, gloss: LOOK !== "brick" && LOOK !== "over", solid: true, inner: "position:absolute;inset:0;display:flex;justify-content:center", style: sel ? "outline:2.5px solid #fff;outline-offset:1px;" : "" });
	}
	function slots(list, o = {}) {
		const size = DESK ? 46 : 34, gap = 4, n = 7;
		const w = n * size + (n - 1) * gap;
		let s = TRAYS ? `<div style="left:${-w / 2 - 7}px;bottom:-6px;width:${w + 14}px;height:${size + 12}px;box-sizing:border-box;border-radius:12px;background:linear-gradient(180deg, rgba(120,200,255,.4), rgba(10,50,110,.5));border:2px solid rgba(255,255,255,.88);box-shadow:0 0 0 1.5px rgba(4,30,70,.5)"><div style="position:absolute;left:6px;right:6px;top:2px;height:40%;border-radius:9px 9px 60% 60%;background:linear-gradient(180deg, rgba(255,255,255,.45), rgba(255,255,255,0))"></div></div>` : "";
		for (let i = 0; i < n; i++) {
			s += `<div style="left:${-w / 2 + i * (size + gap)}px;bottom:0">${slot(list[i], size, o.sel === i)}</div>`;
		}
		if (list.length || o.label) {
			s += `<div style="left:${-w / 2}px;bottom:${size + (TRAYS ? 11 : 6)}px">${T(o.label || `${list.length} CAUGHT`, 11, "#9cf06a", "thin")}</div>`;
		}
		return s;
	}

	// A wild fish's tag, as the reference stacks it: what kind, its rarity, its name, what it needs
	function tagV2(m, o) {
		const k = (o.big ? (REF ? 1.25 : 1) : Math.max(0.72, Math.min(0.88, m.k / (7 * S)))) * S * (DESK ? 1.3 : 1);
		const needC = o.state === "no" ? "#ff6468" : o.state === "short" ? "#ffd23f" : "#8df06a";
		const top = o.kind ? `<div class="rowx" style="gap:5px">${o.kind.map((w) => T(w, 8.5, w === "GOLD" ? "#ffd23f" : w === "BIG" ? "#ffb057" : w === "new!" ? "#ff5a6e" : "#dfe7f2", "thin")).join("")}</div>` : "";
		const hold = o.hold ? `<div class="rowx" style="gap:4px;margin-top:1px">${T(o.hold, 11.5, needC)}</div>` : "";
		const s = `<div class="colx" style="transform:translate(-50%,-100%);gap:0">${top}${tierText(o.tier, 12)}<div style="margin-top:-2px">${T(o.name, 13.5)}</div>`
			+ `<div class="rowx" style="gap:3px;margin-top:-1px"><span class="t thin" style="font-size:9.5px;font-style:italic">Needs</span>${icBubble(12)}${T(o.need, 12, needC)}</div>${hold}</div>`;
		return `<div class="grp" style="left:${m.x}px;top:${m.top - 2 * k}px;transform:scale(${k});transform-origin:0 0">${s}</div>`;
	}

	// The catch banner (the reference: tilted, at the left, with the animal's picture)
	function caughtBanner(name, tier, shout) {
		const title = GT("TAMED!", 23, [226, 255, 170], [124, 224, 75]);
		const b = plate(LOOK === "bubble" ? [20, 110, 70] : [28, 110, 62], `<div class="rowx" style="gap:8px">${thumb(name.replace(/ /g, ""), 40, 34)}${title}</div>`, { pad: "3px 16px 4px 8px", r: LOOK === "brick" || LOOK === "over" ? 9 : 16, major: true, style: LOOK === "bubble" ? "border-color:#9cf06a;" : "", see: REF ? ["rgba(14,64,36,.76)", "#5be06a"] : undefined });
		return `<div style="left:0;top:0;transform:rotate(-6deg);transform-origin:0 100%"><div class="t thin" style="font-size:10.5px;color:#ffb057;margin:0 0 3px 10px">${shout}</div>${b}`
			+ `<div class="rowx" style="gap:6px;margin:6px 0 0 14px">${tierText(tier, 12)}${T(name, 13)}</div></div>`;
	}

	// A miss: the reference offers a revive at the top (whether we have revives is not decided)
	function reviveBar() {
		const heart = `<div style="position:relative;width:44px;height:44px;border-radius:50%;background:${rgb(darken(NAVY, 0.45))};border:3px dotted #ff4f7b;box-sizing:border-box;display:flex;align-items:center;justify-content:center;box-shadow:0 0 0 2.5px ${INKC}">${icHeart(24)}</div>`;
		const btn = plate(LIME, `<div class="colx">${T("Revive", 14)}<div style="margin-top:1px;padding:0 9px;border-radius:999px;background:${rgb(darken(LIME, 0.62))};font-size:11px;color:#d8ff8a">FREE</div></div>`, { pad: "3px 14px 4px", r: LOOK === "bubble" ? 12 : 8, solid: true });
		const inner = `<div class="rowx" style="gap:10px"><div style="margin-left:-20px">${heart}</div><div><div>${T("Keep diving!", 16)}</div><div>${T("1 of 3 free revives", 10, "#dfe7f2", "thin")}</div></div>${btn}</div>`;
		return `<div style="transform:translateX(-50%)">${plate(LOOK === "bubble" ? [40, 70, 110] : [44, 58, 84], inner, { pad: "5px 8px 6px 10px", r: LOOK === "brick" || LOOK === "over" ? 10 : 22, major: true, alpha: 0.94, see: REF ? ["rgba(40,52,76,.88)", rgb(SK.ink)] : undefined })}</div>`;
	}

	// The end of a dive, as the reference has it once you are back at the hub: the title in gold on a dark streak that
	// fades out at both ends, a little tilted, and under it a pill with your catch as round portraits and the count
	function greatBand(list) {
		const round = (name, tier) => `<div style="width:34px;height:34px;border-radius:50%;box-sizing:border-box;background:linear-gradient(180deg, ${rgb(lighten(TILE[tier], 0.25))}, ${rgb(TILE[tier])});border:2.5px solid ${LOOK === "bubble" ? "#fff" : INKC};overflow:hidden;display:flex;align-items:center;justify-content:center">${thumb(name.replace(/ /g, ""), 28, 24)}</div>`;
		const line = (y) => `<div style="position:absolute;left:0;right:0;${y}:0;height:2.5px;background:linear-gradient(90deg, rgba(255,210,63,0), #ffd23f 25%, #ffd23f 75%, rgba(255,210,63,0))"></div>`;
		const tex = LOOK === "bubble" || LOOK === "mix" ? texBubbles() : texStud(0.5);
		const title = `<div style="left:-220px;top:0;width:440px;height:60px;transform:rotate(-2.5deg);background:linear-gradient(90deg, rgba(10,32,64,0), rgba(10,32,64,.9) 24%, rgba(10,32,64,.9) 76%, rgba(10,32,64,0));display:flex;align-items:center;justify-content:center">`
			+ `<div style="position:absolute;inset:0;-webkit-mask-image:linear-gradient(90deg, transparent, #000 30%, #000 70%, transparent)">${tex.replace("<div style=\"", "<div style=\"position:absolute;")}</div>${line("top")}${line("bottom")}<div style="position:relative">${GT("GREAT DIVE!", 42, [255, 244, 170], [255, 170, 40])}</div></div>`;
		const pill = plate(LOOK === "bubble" ? [16, 60, 120] : [20, 44, 80], `<div class="rowx" style="gap:5px">${list.map((x) => round(x[0], x[1])).join("")}<div style="margin-left:7px">${T("You caught ", 15)}${T(String(list.length), 17, "#ffd23f")}${T("!", 15)}</div><div class="rowx" style="margin-left:12px;gap:5px">${T("141 m", 13)}${T("NEW BEST", 10, "#ffd23f", "thin")}</div></div>`, { pad: "4px 16px 4px 5px", r: 999, lip: false, tex: false, gloss: false, alpha: 0.94, style: "outline:2.5px solid #ffd23f;outline-offset:1px;" });
		return title + `<div style="left:0;top:74px;transform:translateX(-50%)">${pill}</div>`;
	}

	// The dock's two big buttons (the reference: Shop and Index at the left edge)
	function sideButton(c, icon, text, badge) {
		const inner = `<div class="rowx" style="gap:8px;height:100%">${icon}${T(text, 15)}</div>`;
		return `<div style="position:relative;margin-bottom:8px">${plate(c, inner, { w: 104, h: 38, pad: "0 0 0 8px", inner: "height:100%", major: true, solid: true })}`
			+ (badge ? `<div style="position:absolute;right:-7px;top:-7px;width:18px;height:18px;border-radius:50%;background:#ff3b4e;border:2px solid #fff;box-shadow:0 0 0 1.5px ${INKC};font-size:12px;line-height:17px;text-align:center;color:#fff;box-sizing:border-box">!</div>` : "") + `</div>`;
	}

	// A shop panel in the reference's build: a bright header with a close button, a dark body, cards by rarity
	function aurasPanel() {
		const card = (name, lvl, tier, mult, price, state, halo) => {
			const c = TILE[tier];
			const well = `<div style="position:relative;width:100%;height:74px;border-radius:5px;box-sizing:border-box;background:#f6ecd4;border:2.5px solid ${LOOK === "bubble" ? "rgba(255,255,255,.9)" : INKC};overflow:hidden;background-image:radial-gradient(circle, rgba(120,90,40,.16) 0 1px, transparent 1.2px);background-size:7px 7px">`
				+ `<div style="position:absolute;left:50%;top:50%;width:60px;height:60px;margin:-30px;border-radius:50%;background:radial-gradient(circle, ${rgba(halo, 0)} 34%, ${rgba(halo, 0.85)} 52%, ${rgba(halo, 0)} 70%)"></div>`
				+ `<div style="position:absolute;left:50%;top:14px;margin-left:-8px;width:16px;height:14px;border-radius:3px;background:${rgb(halo)};border:2px solid ${INKC}"></div><div style="position:absolute;left:50%;top:29px;margin-left:-12px;width:24px;height:22px;border-radius:3px;background:${rgb(darken(halo, 0.12))};border:2px solid ${INKC}"></div><div style="position:absolute;left:50%;top:52px;margin-left:-10px;width:8px;height:14px;background:${rgb(darken(halo, 0.25))};border:2px solid ${INKC}"></div><div style="position:absolute;left:50%;top:52px;margin-left:2px;width:8px;height:14px;background:${rgb(darken(halo, 0.25))};border:2px solid ${INKC}"></div></div>`;
			const btn = state === "equipped" ? plate(AQUA, T("Equipped", 12.5), { pad: "2px 0 3px", inner: "text-align:center", r: 6, style: "width:100%;", solid: true })
				: state === "own" ? plate(LIME, T("Equip", 12.5), { pad: "2px 0 3px", inner: "text-align:center", r: 6, style: "width:100%;", solid: true })
				: plate(state === "poor" ? GREY : LIME, `<div class="rowx" style="justify-content:center;gap:4px">${icCoin(15)}${T(price, 13)}</div>`, { pad: "2px 0 3px", r: 6, style: "width:100%;", solid: true });
			const inner = `<div class="colx" style="gap:3px">${T(name, 10.5, "#fff", "thin")}<div class="rowx" style="gap:4px;margin-top:-2px">${T("Lvl " + lvl, 10, "#fff", "thin")}${tierText(tier, 10)}</div>${well}`
				+ `<div class="rowx" style="gap:4px;margin:1px 0">${T(mult, 15, "#9cf06a")}${icBubble(15)}${T("Oxygen", 13)}</div>${btn}</div>`;
			return plate(c, inner, { w: 122, pad: "5px 7px 9px", r: LOOK === "bubble" ? 12 : 8, solid: true, style: state === "equipped" ? "outline:2.5px solid #fff;outline-offset:1px;" : "" });
		};
		const header = plate(LOOK === "bubble" ? [60, 150, 230] : [72, 160, 245], `<div class="rowx" style="justify-content:center;position:relative">${T("AURAS", 21)}<div style="position:absolute;left:0;top:1px">${icBubble(22)}</div>`
			+ `<div style="position:absolute;right:-2px;top:-1px">${plate(CORAL, `<div class="t thin" style="font-size:14px;line-height:19px">X</div>`, { w: 26, h: 26, pad: "0", r: 6, inner: "text-align:center", lip: false, solid: true })}</div></div>`, { pad: "4px 8px 5px", r: LOOK === "bubble" ? 14 : 8, solid: true, style: "margin:-3px -3px 9px;" });
		const body = `<div>${header}<div class="rowx" style="gap:9px;align-items:flex-start">${card("Pearl Aura", 1, "Common", "x1.5", "", "own", [210, 216, 228])}${card("Kelp Aura", 2, "Common", "x2", "", "equipped", [110, 220, 110])}${card("Tide Aura", 3, "Uncommon", "x2.5", "5K", "buy", [60, 210, 230])}${card("Storm Aura", 4, "Rare", "x3", "1.5M", "poor", [70, 110, 250])}</div>`
			+ `<div style="text-align:center;margin-top:9px">${T("Auras multiply the Oxygen you train", 10.5, "#dfe7f2", "thin")}</div></div>`;
		return `<div style="transform:translate(-50%,-50%)">${plate(LOOK === "bubble" ? [16, 60, 120] : [26, 44, 78], body, { pad: "3px 3px 9px", r: LOOK === "bubble" ? 18 : 10, major: true, shell: true, gloss: false, alpha: 0.96, inner: "padding:0 9px 0" })}</div>`;
	}

	// ---------------------------------------------------------------- a stand-in for the dock (the hub), not the map
	function dockScene() {
		const sand = [242, 222, 160], wall = [176, 168, 150];
		let s = `<svg class="abs" width="${W}" height="${H}" viewBox="0 0 844 390" preserveAspectRatio="none" style="left:0;top:0">`;
		s += `<defs><linearGradient id="dsky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3f9be0"/><stop offset="1" stop-color="#bfe6f5"/></linearGradient></defs><rect width="844" height="390" fill="url(#dsky)"/>`;
		s += `<polygon points="0,150 844,150 844,96 620,96 620,112 300,112 300,90 0,90" fill="${rgb(wall)}"/><polygon points="0,90 300,90 300,82 0,82" fill="${rgb(lighten(sand, 0.2))}"/><polygon points="300,112 620,112 620,104 300,104" fill="${rgb(lighten(sand, 0.2))}"/><polygon points="620,96 844,96 844,88 620,88" fill="${rgb(lighten(sand, 0.2))}"/>`;
		for (let r = 0; r < 14; r++) {
			const y0 = 150 + (240 * r * r) / 196, y1 = 150 + (240 * (r + 1) * (r + 1)) / 196;
			const n = 26;
			for (let i = -n; i < n; i++) {
				const p = (y) => 422 + (i * 42 * (y - 96)) / 54 / 4.2;
				const q2 = (y) => 422 + ((i + 1) * 42 * (y - 96)) / 54 / 4.2;
				s += `<polygon points="${p(y0)},${y0} ${q2(y0)},${y0} ${q2(y1)},${y1} ${p(y1)},${y1}" fill="${rgb((i + r) % 2 ? sand : shade(sand, 0.94))}"/>`;
			}
		}
		// three tanks along the far wall
		for (const [x, w] of [[120, 150], [330, 190], [580, 150]]) {
			s += `<rect x="${x}" y="100" width="${w}" height="62" fill="rgba(90,190,235,.55)" stroke="#1d3557" stroke-width="5"/><rect x="${x + 4}" y="104" width="${w - 8}" height="10" fill="rgba(255,255,255,.35)"/>`;
			s += `<rect x="${x + w / 2 - 26}" y="166" width="52" height="12" fill="#f4b860" stroke="#1d3557" stroke-width="2"/>`;
		}
		// the player, from behind
		const cx = 422, cy = 250, u = 9;
		s += `<rect x="${cx - 2 * u}" y="${cy}" width="${1.8 * u}" height="${3.6 * u}" fill="#2f6fd0"/><rect x="${cx + 0.2 * u}" y="${cy}" width="${1.8 * u}" height="${3.6 * u}" fill="#2f6fd0"/>`;
		s += `<rect x="${cx - 2.1 * u}" y="${cy - 3.6 * u}" width="${4.2 * u}" height="${3.8 * u}" rx="3" fill="#3d8bf0"/><rect x="${cx - 3.4 * u}" y="${cy - 3.5 * u}" width="${1.2 * u}" height="${3.4 * u}" rx="3" fill="#f2c9a0"/><rect x="${cx + 2.2 * u}" y="${cy - 3.5 * u}" width="${1.2 * u}" height="${3.4 * u}" rx="3" fill="#f2c9a0"/><rect x="${cx - 1.4 * u}" y="${cy - 6.2 * u}" width="${2.8 * u}" height="${2.6 * u}" rx="4" fill="#3a2a22"/>`;
		s += "</svg>";
		return s;
	}

	// ---------------------------------------------------------------- the frames
	root.className = "v2";
	let out = "";
	const g = grp;
	const leftX = INS, topStats = DESK ? null : 58;
	const statsAt = (o2, c2, opt) => (DESK ? g("bl", 16 / S + 0, -(opt && opt.boost ? 112 : 78), `<div style="transform:scale(1.25);transform-origin:0 100%">${stats(o2, c2, opt)}</div>`) : g("tl", INS, 58, stats(o2, c2, opt)));
	const hopAt = (mode, opt) => g("br", -(DESK ? 54 : INS + 4), DESK ? -44 : -18, hopButton(mode, opt));
	const slotsAt = (list, opt) => g("bc", 0, -10, slots(list, opt));
	const stripAt = (...a) => g("tc", 0, 8, landStrip(...a));
	const diveBack = (o) => {
		const sc = scene(o.land ?? 1, { fish: o.fish, props, flyer: o.flyer, dark: o.dark });
		out += sc.svg + (o.edge ? vignette(o.edge[0], o.edge[1]) : "") + robloxChrome();
		return sc.marks;
	};
	const carried = [["Yellow Tang", "Common"], ["Clownfish", "Common", "BIG"]];

	if (FRAME === "riding" || FRAME === "low") {
		const low = FRAME === "low";
		const m = diveBack({ fish: [rider("clown"), ...herd("parrot", [at("shark", -56, 12, 64, { id: "shark" })])], edge: low ? ["#ff5a5f", 0.45] : null });
		out += tagV2(m.tang, { tier: "Common", name: "Yellow Tang", need: "40", state: "ok" });
		out += tagV2(m.serg, { tier: "Common", name: "Sergeant Major", need: "40", state: "ok", kind: ["GOLD", "new!"] });
		out += tagV2(m.shark, { tier: "Epic", name: "Reef Shark", need: "290", state: "no" });
		out += tagV2(m.parrot, { tier: "Uncommon", name: "Parrotfish", need: "80", state: "ok", big: true, kind: ["BIG"] });
		out += stripAt(1, 0.35, 128, 2.6);
		out += statsAt("100", "$2.8K");
		out += slotsAt(carried);
		out += g("mc", DESK ? (REF ? 78 : 44) : 50, DESK ? (REF ? -6 : 8) : 4, rings(low ? { frac: 0.25, secs: "0.62", tier: "Common", name: "Clownfish", tame: 0.8, low: true } : { frac: 0.8, secs: "2.4", tier: "Common", name: "Clownfish", tame: 0.25 }));
		out += hopAt("hop", { hot: low });
	} else if (FRAME === "hop") {
		const m = diveBack({ fish: [at("clown", -16, 5, 30), ...herd("parrot")], flyer: { x: 0, y: 9, z: 17 } });
		out += tagV2(m.tang, { tier: "Common", name: "Yellow Tang", need: "40", state: "ok" });
		out += tagV2(m.serg, { tier: "Common", name: "Sergeant Major", need: "40", state: "ok", kind: ["GOLD", "new!"] });
		out += tagV2(m.parrot, { tier: "Uncommon", name: "Parrotfish", need: "80", state: "ok", big: true, kind: ["BIG"], hold: "holds 2.0 s" });
		out += g("mc", 0, 0, reticle(0.72));
		out += stripAt(1, 0.4, 131, 2.6);
		out += statsAt("100", "$2.8K");
		out += slotsAt(carried);
		out += hopAt("grab");
	} else if (FRAME === "tamed") {
		const m = diveBack({ fish: [rider("parrot"), ...herd("tang").filter((x) => x.id !== "parrot")] });
		out += tagV2(m.serg, { tier: "Common", name: "Sergeant Major", need: "40", state: "ok", kind: ["GOLD", "new!"] });
		out += tagV2(m.tang, { tier: "Common", name: "Yellow Tang", need: "40", state: "ok", big: true });
		out += stripAt(1, 0.45, 136, 2.6);
		out += statsAt("100", "$2.8K");
		out += g("tl", INS + (DESK ? 30 : 8), DESK ? 190 : 176, caughtBanner("Parrotfish", "Uncommon", "NICE CATCH!"));
		out += slotsAt([...carried, ["Parrotfish", "Uncommon"]], { sel: 2 });
		out += g("mc", DESK ? (REF ? 78 : 44) : 50, DESK ? (REF ? -6 : 8) : 4, rings({ frac: 0.82, secs: "1.6", tier: "Uncommon", name: "Parrotfish", tame: 1 }));
		out += hopAt("hop");
	} else if (FRAME === "miss") {
		diveBack({ fish: [at("tang", 58, 9, 160), at("lion", -50, 8, 200)], flyer: { x: 0, y: 6, z: 19 }, dark: true, edge: ["#000", 0.85] });
		out += stripAt(1, 0.5, 141, 2.6);
		out += statsAt("100", "$2.8K");
		out += g("tc", 10, DESK ? 96 : 84, reviveBar());
		out += g("mc", 0, -8, `<div class="colx" style="transform:translateX(-50%)">${GT("MISSED THE FISH!", 30, [255, 190, 190], [255, 90, 95])}</div>`);
		out += slotsAt([...carried, ["Parrotfish", "Uncommon"]]);
		out += hopAt("off");
	} else if (FRAME === "great") {
		out += dockScene() + robloxChrome();
		out += statsAt("100", "$2.8K");
		out += g(DESK ? "ml" : "tl", DESK ? 16 / S : INS, DESK ? -60 : 132, sideButton([240, 78, 96], icBag(24), "Shop") + sideButton(BLUE, icBook(24), "Index", true));
		out += g("mc", 0, -36, greatBand([["Parrotfish", "Uncommon"], ["Yellow Tang", "Common"], ["Clownfish", "Common"]]));
		out += g("mc", 0, DESK ? 110 : 96, `<div style="transform:translateX(-50%)">${T("GO TO YOUR TANK TO DROP YOUR CATCH", 13)}</div>`);
		out += slotsAt([...carried, ["Parrotfish", "Uncommon"]]);
	} else if (FRAME === "dock") {
		out += dockScene() + robloxChrome();
		out += statsAt("100", "$2.8K", { plus: false });
		out += g(DESK ? "ml" : "tl", DESK ? 16 / S : INS, DESK ? -60 : 132, sideButton([240, 78, 96], icBag(24), "Shop") + sideButton(BLUE, icBook(24), "Index", true));
		out += g("mc", 0, DESK ? 86 : 78, `<div style="transform:translateX(-50%)">${T("GO TO YOUR TANK TO DROP YOUR CATCH", 13)}</div>`);
		out += g("tc", 0, 12, `<div style="transform:translateX(-50%)">${T("Your tank earns ", 14)}${T("$12", 14, "#9cf06a")}${T(" a second", 14)}</div>`);
		out += slotsAt([...carried, ["Parrotfish", "Uncommon"]], { label: "3 TO DROP OFF" });
	} else if (FRAME === "auras") {
		out += dockScene() + `<div class="abs" style="inset:0;background:rgba(6,20,44,.45)"></div>` + robloxChrome();
		out += statsAt("100", "$2.8K");
		out += g("mc", DESK ? 0 : 30, 0, aurasPanel());
	} else if (FRAME === "pieces") {
		out += `<div class="abs" style="inset:0;background:linear-gradient(#2a86c8,#8fd0e0 42%,#f49498 43%,#e88a90)"></div>`;
		out += `<div class="abs" style="left:0;top:8px;width:100%;text-align:center;font:bold 20px Arial;color:#fff;text-shadow:0 2px 0 #10243f">${SK.name}</div>`;
		out += g("tc", 0, 40, landStrip(1, 0.35, 128, 2.6));
		out += g("tl", 30, 150, rings({ frac: 0.8, secs: "2.4", tier: "Common", name: "Clownfish", tame: 0.4 }));
		out += g("tl", 176, 154, rings({ frac: 0.25, secs: "0.62", tier: "Rare", name: "Moray Eel", tame: 1, low: true }));
		out += g("tl", 24, 222, stats("1.9K", "$2.8M", { plus: true }));
		out += g("tl", 330, 150, `<div class="colx" style="gap:0">${T("GOLD", 8.5, "#ffd23f", "thin")}${tierText("Legendary", 13)}<div style="margin-top:-2px">${T("Dunkleosteus", 14.5)}</div><div class="rowx" style="gap:3px"><span class="t thin" style="font-size:10px;font-style:italic">Needs</span>${icBubble(13)}${T("12.5K", 13, "#ff6468")}</div></div>`);
		out += g("tl", 24, 300, sideButton([240, 78, 96], icBag(24), "Shop") + sideButton(BLUE, icBook(24), "Index", true));
		out += g("tl", 204, 366, caughtBanner("Parrotfish", "Uncommon", "NICE CATCH!"));
		out += g("tl", 190, 448, `<div style="left:0;top:0">${[["Clownfish", "Common"], ["Parrotfish", "Uncommon", "BIG"], ["Moray Eel", "Rare"], ["Reef Shark", "Epic"], ["Dunkleosteus", "Legendary", "GOLD"], ["Kraken", "Mythic"], null].map((it, i) => `<div style="position:absolute;left:${i * 38}px;top:0">${slot(it, 34, i === 1)}</div>`).join("")}</div>`);
		out += g("tl", 60, 500, `<div style="transform:none">${reviveBar().replace("transform:translateX(-50%)", "")}</div>`);
		out += g("tl", 600, 250, hopButton("hop"));
		out += g("tl", 600, 356, hopButton("grab"));
	}
	root.innerHTML = out;
})();

#!/usr/bin/env python3
"""Generates assets/hero.svg — the animated README hero.

Pure SVG + CSS keyframes (no scripts), so it plays when GitHub renders it via <img>.
Every track shares one loop length, which keeps the scene in sync forever.
Run:  python3 assets/make_hero.py        (English  → hero.svg)
      python3 assets/make_hero.py zh     (Chinese  → hero.zh-CN.svg)
"""
import sys
from pathlib import Path

LANG = sys.argv[1] if len(sys.argv) > 1 else "en"
S = {
    "en": dict(
        out="hero.svg", type_w=344,
        thought="make job title optional \u2014 ask again after first use",
        placeholder="Jot a thought\u2026 or / to ask AI",
        cap1="Select anything, in any app", cap2="Press Option + T",
        cap3="Type one line", cap4="Enter. It\u2019s in your notes.",
        card1=["Courier routes drawn live = a city\u2019s bloodstream"],
        card2=["Linear files an issue in one keystroke.", "We need three clicks. Too heavy."],
        aria="Eureka demo: select text in any app, press Option+T, type one line, press Enter. "
             "The thought appears as a colored card in Obsidian, with its source.",
    ),
    "zh": dict(
        out="hero.zh-CN.svg", type_w=262,
        thought="job title \u6539\u6210\u53ef\u8df3\u8fc7\uff0c\u9996\u6b21\u4f7f\u7528\u540e\u518d\u95ee",
        placeholder="\u8bb0\u4e2a\u60f3\u6cd5\u2026 \u6216 / \u95ee AI",
        cap1="\u5728\u4efb\u610f\u5e94\u7528\u91cc\u9009\u4e2d\u6587\u5b57", cap2="\u6309\u4e0b Option + T",
        cap3="\u5199\u4e00\u53e5\u8bdd", cap4="\u56de\u8f66\uff0c\u5df2\u7ecf\u5728\u4f60\u7684\u7b14\u8bb0\u91cc\u4e86",
        card1=["\u628a\u5168\u57ce\u9a91\u624b\u7684\u5b9e\u65f6\u8def\u7ebf\u753b\u51fa\u6765 = \u57ce\u5e02\u7684\u8840\u7ba1\u7cfb\u7edf"],
        card2=["Linear \u5efa issue \u53ea\u8981\u4e00\u4e2a\u5feb\u6377\u952e\u3002", "\u6211\u4eec\u8981\u70b9\u4e09\u6b21\uff0c\u592a\u91cd\u4e86\u3002"],
        aria="Eureka \u6f14\u793a\uff1a\u5728\u4efb\u610f\u5e94\u7528\u9009\u4e2d\u6587\u5b57\uff0c\u6309 Option+T\uff0c\u5199\u4e00\u53e5\u8bdd\uff0c\u56de\u8f66\u3002"
             "\u60f3\u6cd5\u4f1a\u5e26\u7740\u6765\u6e90\uff0c\u4ee5\u5f69\u8272\u5361\u7247\u7684\u5f62\u5f0f\u51fa\u73b0\u5728 Obsidian \u91cc\u3002",
    ),
}[LANG]

T = 10.0  # loop length in seconds
EASE_OUT = "cubic-bezier(.2,.8,.2,1)"
EASE_IO = "cubic-bezier(.45,0,.25,1)"
SPRING = "cubic-bezier(.3,1.5,.5,1)"

FONT = ('-apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI","PingFang SC",'
        '"Helvetica Neue",Arial,sans-serif')

css_blocks = []


def track(name, frames):
    """frames: [(time_s, {prop: value}, easing-to-next | None)]"""
    out = [f"@keyframes {name}{{"]
    frames = sorted(frames, key=lambda f: f[0])
    if frames[0][0] > 0:
        frames.insert(0, (0.0, frames[0][1], None))
    if frames[-1][0] < T:
        frames.append((T, frames[-1][1], None))
    for t, props, *rest in frames:
        ease = rest[0] if rest else None
        body = ";".join(f"{k}:{v}" for k, v in props.items())
        if ease:
            body += f";animation-timing-function:{ease}"
        out.append(f"{t / T * 100:.2f}%{{{body}}}")
    out.append("}")
    css_blocks.append("".join(out))
    css_blocks.append(f".{name}{{animation:{name} {T}s linear infinite}}")


def fade(name, t_in, t_out, d_in=0.3, d_out=0.3):
    track(name, [
        (max(t_in - 0.001, 0), {"opacity": 0}, EASE_OUT),
        (t_in + d_in, {"opacity": 1}),
        (t_out, {"opacity": 1}, EASE_IO),
        (t_out + d_out, {"opacity": 0}),
    ])


# ───────────────────────── timeline ─────────────────────────
SEL_START, SEL_END = 0.8, 1.7
KEY_IN, KEY_PRESS, KEY_OUT = 1.9, 2.25, 2.9
PANEL_IN = 2.4
TYPE_START, TYPE_END = 3.0, 5.3
RET_IN, RET_PRESS, RET_OUT = 5.35, 5.65, 6.2
PANEL_OUT = 5.8
CARD_IN = 6.0
RESET = 9.35

# cursor (arrow) — positions are in the left window's coordinate space
track("cursor", [
    (0.0, {"transform": "translate(250px,250px)"}, EASE_IO),
    (SEL_START, {"transform": "translate(30px,264px)"}, EASE_IO),
    (SEL_END, {"transform": "translate(378px,270px)"}),
    (RESET - 0.4, {"transform": "translate(378px,270px)"}, EASE_IO),
    (T, {"transform": "translate(250px,250px)"}),
])

# text selection highlight
track("select", [
    (SEL_START, {"transform": "scaleX(0)", "opacity": 1}, EASE_IO),
    (SEL_END, {"transform": "scaleX(1)", "opacity": 1}),
    (PANEL_OUT + 0.2, {"transform": "scaleX(1)", "opacity": 1}),
    (PANEL_OUT + 0.6, {"transform": "scaleX(1)", "opacity": 0}),
    (T, {"transform": "scaleX(0)", "opacity": 0}),
])

# ⌥ T keycaps
track("keys", [
    (KEY_IN - 0.001, {"opacity": 0, "transform": "translateY(8px)"}, EASE_OUT),
    (KEY_IN + 0.25, {"opacity": 1, "transform": "translateY(0)"}),
    (KEY_OUT, {"opacity": 1, "transform": "translateY(0)"}, EASE_IO),
    (KEY_OUT + 0.3, {"opacity": 0, "transform": "translateY(0)"}),
])
for cls, delay in (("capA", 0.0), ("capB", 0.08)):
    track(cls, [
        (KEY_PRESS + delay, {"transform": "translateY(0)"}, EASE_OUT),
        (KEY_PRESS + delay + 0.1, {"transform": "translateY(4px)"}),
        (KEY_PRESS + delay + 0.3, {"transform": "translateY(4px)"}, EASE_OUT),
        (KEY_PRESS + delay + 0.45, {"transform": "translateY(0)"}),
    ])

# return keycap
track("ret", [
    (RET_IN - 0.001, {"opacity": 0, "transform": "translateY(8px)"}, EASE_OUT),
    (RET_IN + 0.2, {"opacity": 1, "transform": "translateY(0)"}),
    (RET_PRESS, {"opacity": 1, "transform": "translateY(0)"}, EASE_OUT),
    (RET_PRESS + 0.1, {"opacity": 1, "transform": "translateY(4px)"}),
    (RET_PRESS + 0.28, {"opacity": 1, "transform": "translateY(0)"}),
    (RET_OUT, {"opacity": 1, "transform": "translateY(0)"}, EASE_IO),
    (RET_OUT + 0.3, {"opacity": 0, "transform": "translateY(0)"}),
])

# capture panel
track("panel", [
    (PANEL_IN - 0.001, {"opacity": 0, "transform": "translateY(10px) scale(.96)"}, EASE_OUT),
    (PANEL_IN + 0.3, {"opacity": 1, "transform": "translateY(0) scale(1)"}),
    (PANEL_OUT, {"opacity": 1, "transform": "translateY(0) scale(1)"}, EASE_IO),
    (PANEL_OUT + 0.25, {"opacity": 0, "transform": "translateY(-6px) scale(.98)"}),
])
fade("placeholder", PANEL_IN, TYPE_START - 0.05, 0.3, 0.05)
TYPE_W = S["type_w"]
track("wipe", [
    (TYPE_START, {"transform": "translateX(0)"}),
    (TYPE_END, {"transform": f"translateX({TYPE_W}px)"}),
    (PANEL_OUT + 0.3, {"transform": f"translateX({TYPE_W}px)"}),
    (PANEL_OUT + 0.31, {"transform": "translateX(0)"}),
])

# captions
fade("cap1", 0.25, SEL_END + 0.05, 0.3, 0.2)
fade("cap2", KEY_IN, TYPE_START - 0.2, 0.25, 0.2)
fade("cap3", TYPE_START, RET_IN - 0.15, 0.25, 0.15)
fade("cap4", RET_IN, RESET, 0.25, 0.3)

# the new card in Obsidian
track("card", [
    (CARD_IN - 0.001, {"opacity": 0, "transform": "translateY(22px) scale(.97)"}, SPRING),
    (CARD_IN + 0.55, {"opacity": 1, "transform": "translateY(0) scale(1)"}),
    (RESET, {"opacity": 1, "transform": "translateY(0) scale(1)"}, EASE_IO),
    (RESET + 0.4, {"opacity": 0, "transform": "translateY(0) scale(1)"}),
])
track("glow", [
    (CARD_IN, {"opacity": 0}, EASE_OUT),
    (CARD_IN + 0.4, {"opacity": .9}, EASE_IO),
    (CARD_IN + 1.6, {"opacity": 0}),
])

# floating bubble: bounce + colour shift when the thought lands
track("bubble", [
    (CARD_IN, {"transform": "scale(1)"}, EASE_OUT),
    (CARD_IN + 0.12, {"transform": "scale(1.35)"}, EASE_IO),
    (CARD_IN + 0.3, {"transform": "scale(.92)"}, EASE_IO),
    (CARD_IN + 0.5, {"transform": "scale(1)"}),
])
track("bubbleCoral", [
    (CARD_IN, {"opacity": 0}, EASE_OUT),
    (CARD_IN + 0.5, {"opacity": 1}),
    (RESET, {"opacity": 1}, EASE_IO),
    (RESET + 0.4, {"opacity": 0}),
])

# ───────────────────────── drawing helpers ─────────────────────────

def window(x, y, w, h, body, title="", pill=""):
    dots = "".join(
        f'<circle cx="{20 + i * 18}" cy="20" r="5.5" fill="{c}"/>'
        for i, c in enumerate(("#ff5f57", "#febc2e", "#28c840")))
    head = ""
    if pill:
        head = (f'<rect x="{w / 2 - 110}" y="9" width="220" height="22" rx="11" fill="#f1f1f4"/>'
                f'<text x="{w / 2}" y="24.5" class="t mut" font-size="11.5" text-anchor="middle">{pill}</text>')
    if title:
        head = (f'<rect x="84" y="8" width="132" height="32" rx="8" fill="#fff"/>'
                f'<text x="100" y="28.5" class="t" font-size="12.5" fill="#444">{title}</text>')
    return f'''
<g transform="translate({x},{y})">
  <rect width="{w}" height="{h}" rx="14" fill="#fff" filter="url(#winShadow)"/>
  <path d="M0 14a14 14 0 0 1 14-14h{w - 28}a14 14 0 0 1 14 14v26H0z" fill="#f7f7f9"/>
  <rect y="40" width="{w}" height="1" fill="#ececf0"/>
  {dots}{head}
  {body}
</g>'''


def bar(x, y, w, h=9, fill="#e9e9ee"):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{h / 2}" fill="{fill}"/>'


SPARK = ('M6 0 L7.4 4.6 L12 6 L7.4 7.4 L6 12 L4.6 7.4 L0 6 L4.6 4.6 Z '
         'M11.5 0.5 l.6 1.6 1.6 .6 -1.6 .6 -.6 1.6 -.6 -1.6 -1.6 -.6 1.6 -.6 Z')


def card(y, h, grad, color, time, lines, extra="", cls="", after=""):
    text = "".join(
        f'<text x="16" y="{52 + i * 21}" class="t" font-size="14" fill="#2b2b2f">{l}</text>'
        for i, l in enumerate(lines))
    return f'''
<g transform="translate(32,{y})">
  <g class="{cls}" style="transform-box:fill-box;transform-origin:50% 50%">
    {extra}
    <rect width="456" height="{h}" rx="10" fill="url(#{grad})"/>
    <path d="{SPARK}" transform="translate(16,14)" fill="{color}" opacity=".7"/>
    <text x="35" y="25" class="t" font-size="11.5" fill="{color}" opacity=".85">{time}</text>
    {text}
    {after}
  </g>
</g>'''


def keycap(x, w, inner, cls):
    return f'''
<g transform="translate({x},0)"><g class="{cls}">
  <rect y="4" width="{w}" height="54" rx="12" fill="#d9d9e2"/>
  <rect width="{w}" height="54" rx="12" fill="#fff" stroke="#e3e3ea"/>
  {inner}
</g></g>'''


# ───────────────────────── scene ─────────────────────────
QUOTE = "Step 3: “Tell us about yourself” — 42% drop-off"
THOUGHT = S["thought"]

funnel = "".join(
    f'<rect x="{32 + i * 62}" y="{222 - h}" width="44" height="{h}" rx="6" fill="{c}"/>'
    f'<rect x="{36 + i * 62}" y="232" width="36" height="6" rx="3" fill="#ececf0"/>'
    for i, (h, c) in enumerate(((76, "#dfe6f7"), (60, "#dfe6f7"), (33, "#f6c1b8"), (28, "#dfe6f7"))))

left_body = f'''
  {bar(32, 70, 210, 13, "#d4d4dc")}
  {bar(32, 98, 430)}{bar(32, 116, 380)}
  {funnel}
  {bar(300, 150, 170)}{bar(300, 170, 150)}{bar(300, 190, 176)}{bar(300, 210, 120)}
  <g transform="translate(28,258)">
    <rect class="select" width="350" height="28" rx="5" fill="#6180d9" fill-opacity=".24"
          style="transform-box:fill-box;transform-origin:0 50%"/>
  </g>
  <text x="32" y="277" class="t" font-size="15" fill="#2b2b2f" textLength="342"
        lengthAdjust="spacingAndGlyphs">{QUOTE}</text>
  {bar(32, 308, 440)}{bar(32, 326, 300)}{bar(32, 344, 400)}{bar(32, 362, 250)}
'''

panel = f'''
<g transform="translate(116,366)">
  <g class="panel" style="transform-box:fill-box;transform-origin:50% 0">
    <rect width="440" height="96" rx="13" fill="#fff" filter="url(#panelShadow)"/>
    <rect x="12" y="11" width="416" height="27" rx="8" fill="#000" fill-opacity=".04"/>
    <text x="22" y="29" class="t" font-size="11.5" fill="#8c8c92">{QUOTE}</text>
    <g clip-path="url(#inputClip)">
      <text x="17" y="66" class="t" font-size="14" fill="#55555c" textLength="{TYPE_W - 6}"
            lengthAdjust="spacingAndGlyphs">{THOUGHT}</text>
      <g class="wipe">
        <rect x="16" y="46" width="{TYPE_W + 40}" height="28" fill="#fff"/>
        <rect class="caret" x="17" y="51" width="1.6" height="19" rx=".8" fill="#6180d9"/>
      </g>
    </g>
    <text class="t placeholder" x="22" y="66" font-size="14" fill="#b9b9c0">{S["placeholder"]}</text>
    <text x="428" y="86" class="t" font-size="10" fill="#b9b9c0" text-anchor="end">↵ save · esc</text>
  </g>
</g>'''

OPT = '<path d="M17 19h8l10 16h6M31 19h10" fill="none" stroke="#55555c" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
RET = '<path d="M56 18v12a4 4 0 0 1-4 4H28m0 0 7-7m-7 7 7 7" fill="none" stroke="#55555c" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
keys = f'''
<g transform="translate(316,486)">
  <g class="keys">
    {keycap(-64, 58, OPT, "capA")}
    {keycap(6, 58, '<text x="29" y="35" class="t" font-size="20" font-weight="600" fill="#55555c" text-anchor="middle">T</text>', "capB")}
  </g>
  <g class="ret">{keycap(-42, 84, RET, "")}</g>
  <g font-size="16" text-anchor="middle" class="t" fill="#6b6b75" font-weight="500">
    <text class="cap1" y="102">{S["cap1"]}</text>
    <text class="cap2" y="102">{S["cap2"]}</text>
    <text class="cap3" y="102">{S["cap3"]}</text>
    <text class="cap4" y="102">{S["cap4"]}</text>
  </g>
</g>'''

GLOW = ('<rect class="glow" x="-5" y="-5" width="466" height="130" rx="14" fill="none" '
        'stroke="#e66b80" stroke-opacity=".45" stroke-width="2" filter="url(#soft)"/>')
QUOTE_BLOCK = f'''<rect x="16" y="66" width="2" height="40" rx="1" fill="#000" fill-opacity=".15"/>
    <text x="28" y="81" class="t" font-size="12.5" font-style="italic" fill="#77777f">{QUOTE}</text>
    <text x="28" y="100" class="t" font-size="12.5" fill="#77777f">\u3010<tspan fill="#7a6ad8" text-decoration="underline">mixpanel.com/funnels</tspan>\u3011</text>'''

right_body = f'''
  <text x="260" y="70" class="t" font-size="11" fill="#a0a0a8" text-anchor="middle">Eureka / 2026-06-29 / Thoughts</text>
  <text x="32" y="112" class="t" font-size="22" font-weight="700" fill="#1f1f24">Random Thoughts — 2026-06-29</text>
  {card(134, 72, "gBlue", "#6180d9", "09:12", S["card1"])}
  {card(218, 93, "gPurple", "#9e73d1", "10:40", S["card2"])}
  {card(323, 120, "gCoral", "#e66b80", "11:03", [THOUGHT], cls="card", extra=GLOW, after=QUOTE_BLOCK)}
'''

bubble = '''
<g transform="translate(1146,642)">
  <g class="bubble" style="transform-box:fill-box;transform-origin:50% 50%">
    <circle r="13" fill="url(#dotBlue)"/>
    <circle class="bubbleCoral" r="13" fill="url(#dotCoral)"/>
  </g>
</g>'''

cursor = '''
<g transform="translate(56,64)"><g class="cursor">
  <path d="M0 0v17l4.6-4.2 3 7 2.6-1.1-3-6.9H13z" fill="#1f1f24" stroke="#fff" stroke-width="1.4" stroke-linejoin="round"/>
</g></g>'''


def grad(id_, a, b, alpha=None):
    op = f' stop-opacity="{alpha}"' if alpha else ""
    return (f'<linearGradient id="{id_}" x1="0" y1="0" x2="1" y2="1">'
            f'<stop offset="0" stop-color="{a}"{op}/><stop offset="1" stop-color="{b}"{op}/></linearGradient>')


css_blocks.append("@keyframes blink{0%,55%{opacity:1}56%,100%{opacity:0}}.caret{animation:blink 1s steps(1) infinite}")
css_blocks.append("@keyframes driftA{from{transform:translate(0,0)}to{transform:translate(60px,40px)}}"
                  "@keyframes driftB{from{transform:translate(0,0)}to{transform:translate(-70px,-30px)}}"
                  ".blobA{animation:driftA 10s ease-in-out infinite alternate}"
                  ".blobB{animation:driftB 10s ease-in-out infinite alternate}")
# Without animation support (or with reduced motion) the base styles show the finished scene.
css_blocks.append(".panel,.keys,.ret,.placeholder,.cap1,.cap2,.cap3,.glow{opacity:0}"
                  ".wipe{transform:translateX(%dpx)}" % TYPE_W)
css_blocks.append("@media (prefers-reduced-motion:reduce){*{animation:none!important}}")

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 690" role="img"
     aria-label="{S["aria"]}">
<defs>
  <style>
    .t{{font-family:{FONT}}} .mut{{fill:#8c8c92}}
    {"".join(css_blocks)}
  </style>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#fff4ee"/><stop offset=".5" stop-color="#f6f3ff"/><stop offset="1" stop-color="#eef6ff"/>
  </linearGradient>
  {grad("gBlue", "#e9f3fc", "#e6ebfa")}
  {grad("gPurple", "#f7f0fc", "#efe8f9")}
  {grad("gCoral", "#fdf0e8", "#fbe7ea")}
  <linearGradient id="dotBlue" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8cc7f2"/><stop offset="1" stop-color="#6180d9"/></linearGradient>
  <linearGradient id="dotCoral" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f5a673"/><stop offset="1" stop-color="#e66b80"/></linearGradient>
  <filter id="winShadow" x="-10%" y="-10%" width="120%" height="125%">
    <feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#5b5b8a" flood-opacity=".16"/>
  </filter>
  <filter id="panelShadow" x="-15%" y="-40%" width="130%" height="200%">
    <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#2b2b55" flood-opacity=".22"/>
  </filter>
  <filter id="blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="60"/></filter>
  <filter id="soft" x="-10%" y="-20%" width="120%" height="140%"><feGaussianBlur stdDeviation="3"/></filter>
  <clipPath id="inputClip"><rect x="12" y="44" width="416" height="32"/></clipPath>
  <clipPath id="frame"><rect width="1200" height="690" rx="28"/></clipPath>
</defs>
<g clip-path="url(#frame)">
  <rect width="1200" height="690" fill="url(#bg)"/>
  <circle class="blobA" cx="180" cy="120" r="170" fill="#f5a673" opacity=".22" filter="url(#blur)"/>
  <circle class="blobB" cx="1040" cy="560" r="200" fill="#8cc7f2" opacity=".28" filter="url(#blur)"/>
  <circle class="blobA" cx="640" cy="690" r="150" fill="#d9b3f2" opacity=".25" filter="url(#blur)"/>
  {window(56, 64, 520, 392, left_body, pill="mixpanel.com/funnels")}
  {window(624, 64, 520, 560, right_body, title="Thoughts")}
  {keys}
  {panel}
  {bubble}
  {cursor}
</g>
</svg>
'''

out = Path(__file__).with_name(S["out"])
out.write_text(svg, encoding="utf-8")
print(f"wrote {out} ({len(svg) / 1024:.1f} KB)")

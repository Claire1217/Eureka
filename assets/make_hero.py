#!/usr/bin/env python3
"""Generates assets/hero.svg — the animated README hero.

Two captures in a row, in two very different apps (a web page, then a code
editor), landing in the same Obsidian note: the point is "any app, same hotkey".

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
        out="hero.svg",
        thought_a=("make job title optional — ask again after first use", 338),
        thought_b=("300 ms is too fast to notice — try 500", 250),
        placeholder="Jot a thought… or / to ask AI",
        select="Select anything, in any app", press="Press Option + T", type="Type one line",
        saved="Enter. It’s in your notes.",
        switch="Now a different app — same hotkey", both="Web page or code editor: one note.",
        card1=["Courier routes drawn live = a city’s bloodstream"],
        card2=["Linear files an issue in one keystroke; we need three clicks."],
        aria="Eureka demo. In a web page, a sentence is selected, Option+T is pressed, one line is typed and "
             "Enter saves it: the thought appears in Obsidian as a colored card with the page as its source. "
             "Then the same thing happens in a code editor, and a second card lands in the same note.",
    ),
    "zh": dict(
        out="hero.zh-CN.svg",
        thought_a=("job title 改成可跳过，首次使用后再问", 256),
        thought_b=("300ms 太快，用户根本看不到，改成 500 试试", 272),
        placeholder="记个想法… 或 / 问 AI",
        select="在任意应用里选中文字", press="按下 Option + T", type="写一句话",
        saved="回车，已经在你的笔记里了",
        switch="换一个应用，还是同一个快捷键", both="网页也好，代码编辑器也好，都进同一篇笔记",
        card1=["把全城骑手的实时路线画出来 = 城市的血管系统"],
        card2=["Linear 建 issue 只要一个快捷键，我们要点三次。"],
        aria="Eureka 演示：在网页里选中一句话，按 Option+T，写一句话，回车保存，"
             "想法带着来源以彩色卡片的形式出现在 Obsidian 里。"
             "接着在代码编辑器里重复同样的操作，第二张卡片落进同一篇笔记。",
    ),
}[LANG]

T = 16.0  # loop length in seconds
EASE_OUT = "cubic-bezier(.2,.8,.2,1)"
EASE_IO = "cubic-bezier(.45,0,.25,1)"
SPRING = "cubic-bezier(.3,1.5,.5,1)"
FONT = ('-apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI","PingFang SC",'
        '"Helvetica Neue",Arial,sans-serif')
MONO = 'ui-monospace,SFMono-Regular,Menlo,Consolas,"Liberation Mono",monospace'

css_blocks = []
hidden_at_rest = []  # classes that are invisible when animation is unavailable


def track(name, frames, rest_hidden=False):
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
        out.append(f"{t / T * 100:.3f}%{{{body}}}")
    out.append("}")
    css_blocks.append("".join(out) + f".{name}{{animation:{name} {T}s linear infinite}}")
    if rest_hidden:
        hidden_at_rest.append(name)


def fade(name, t_in, t_out, d_in=0.3, d_out=0.3, rest_hidden=True):
    track(name, [
        (max(t_in - 0.002, 0), {"opacity": 0}, EASE_OUT),
        (t_in + d_in, {"opacity": 1}),
        (t_out, {"opacity": 1}, EASE_IO),
        (t_out + d_out, {"opacity": 0}),
    ], rest_hidden)


def keypress(name, t_in, t_press, t_out):
    track(name, [
        (t_in - 0.002, {"opacity": 0, "transform": "translateY(8px)"}, EASE_OUT),
        (t_in + 0.2, {"opacity": 1, "transform": "translateY(0)"}),
        (t_press, {"opacity": 1, "transform": "translateY(0)"}, EASE_OUT),
        (t_press + 0.1, {"opacity": 1, "transform": "translateY(4px)"}),
        (t_press + 0.3, {"opacity": 1, "transform": "translateY(0)"}),
        (t_out, {"opacity": 1, "transform": "translateY(0)"}, EASE_IO),
        (t_out + 0.3, {"opacity": 0, "transform": "translateY(0)"}),
    ], True)


RESET = 15.2


def capture(p, t0, type_w, type_dur):
    """All tracks of one capture, names prefixed with p. Returns its key moments."""
    sel0, sel1 = t0, t0 + 0.9
    keys_in, panel_in, type0 = t0 + 1.1, t0 + 1.6, t0 + 2.2
    type1 = type0 + type_dur
    ret_in, panel_out, card_in = type1 + 0.05, type1 + 0.5, type1 + 0.7
    track(p + "select", [
        (sel0, {"transform": "scaleX(0)", "opacity": 1}, EASE_IO),
        (sel1, {"transform": "scaleX(1)", "opacity": 1}),
        (panel_out + 0.2, {"transform": "scaleX(1)", "opacity": 1}),
        (panel_out + 0.6, {"transform": "scaleX(1)", "opacity": 0}),
        (T, {"transform": "scaleX(0)", "opacity": 0}),
    ], True)
    keypress(p + "keys", keys_in, keys_in + 0.35, keys_in + 1.0)
    keypress(p + "ret", ret_in, ret_in + 0.3, ret_in + 0.85)
    track(p + "panel", [
        (panel_in - 0.002, {"opacity": 0, "transform": "translateY(10px) scale(.96)"}, EASE_OUT),
        (panel_in + 0.3, {"opacity": 1, "transform": "translateY(0) scale(1)"}),
        (panel_out, {"opacity": 1, "transform": "translateY(0) scale(1)"}, EASE_IO),
        (panel_out + 0.25, {"opacity": 0, "transform": "translateY(-6px) scale(.98)"}),
    ], True)
    fade(p + "placeholder", panel_in, type0 - 0.05, 0.3, 0.05)
    track(p + "wipe", [
        (type0, {"transform": "translateX(0)"}),
        (type1, {"transform": f"translateX({type_w + 6}px)"}),
        (panel_out + 0.3, {"transform": f"translateX({type_w + 6}px)"}),
        (panel_out + 0.31, {"transform": "translateX(0)"}),
    ])
    track(p + "card", [
        (card_in - 0.002, {"opacity": 0, "transform": "translateY(22px) scale(.97)"}, SPRING),
        (card_in + 0.55, {"opacity": 1, "transform": "translateY(0) scale(1)"}),
        (RESET, {"opacity": 1, "transform": "translateY(0) scale(1)"}, EASE_IO),
        (RESET + 0.4, {"opacity": 0, "transform": "translateY(0) scale(1)"}),
    ])
    track(p + "glow", [
        (card_in, {"opacity": 0}, EASE_OUT),
        (card_in + 0.4, {"opacity": .9}, EASE_IO),
        (card_in + 1.6, {"opacity": 0}),
    ], True)
    track(p + "dot", [
        (card_in, {"opacity": 0}, EASE_OUT),
        (card_in + 0.5, {"opacity": 1}),
        (RESET, {"opacity": 1}, EASE_IO),
        (RESET + 0.4, {"opacity": 0}),
    ])
    track(p + "bounce", [
        (card_in, {"transform": "scale(1)"}, EASE_OUT),
        (card_in + 0.12, {"transform": "scale(1.35)"}, EASE_IO),
        (card_in + 0.3, {"transform": "scale(.92)"}, EASE_IO),
        (card_in + 0.5, {"transform": "scale(1)"}),
    ])
    # captions under the window
    fade(p + "capPress", keys_in, type0 - 0.2, 0.25, 0.2)
    fade(p + "capType", type0, ret_in - 0.15, 0.25, 0.15)
    return dict(sel0=sel0, sel1=sel1, keys_in=keys_in, ret_in=ret_in, card_in=card_in)


# ───────────────────────── timeline ─────────────────────────
TA, WA = S["thought_a"]
TB, WB = S["thought_b"]
A = capture("a", 0.8, WA, 2.2)
SWITCH = A["card_in"] + 1.0            # the web page leaves, the editor arrives
B = capture("b", SWITCH + 1.3, WB, 1.6)

track("winA", [
    (0, {"opacity": 1, "transform": "translateX(0) scale(1)"}),
    (SWITCH, {"opacity": 1, "transform": "translateX(0) scale(1)"}, EASE_IO),
    (SWITCH + 0.5, {"opacity": 0, "transform": "translateX(-46px) scale(.97)"}),
    (RESET + 0.2, {"opacity": 0, "transform": "translateX(0) scale(1)"}, EASE_OUT),
    (T, {"opacity": 1, "transform": "translateX(0) scale(1)"}),
], True)
track("winB", [
    (SWITCH + 0.2, {"opacity": 0, "transform": "translateX(46px) scale(.97)"}, EASE_OUT),
    (SWITCH + 0.8, {"opacity": 1, "transform": "translateX(0) scale(1)"}),
    (RESET, {"opacity": 1, "transform": "translateX(0) scale(1)"}, EASE_IO),
    (RESET + 0.4, {"opacity": 0, "transform": "translateX(0) scale(1)"}),
])
fade("capSelect", 0.25, A["sel1"] + 0.05, 0.3, 0.2)
fade("capSaved", A["ret_in"], SWITCH, 0.25, 0.2)
fade("capSwitch", SWITCH + 0.3, B["keys_in"] - 0.1, 0.3, 0.2)
fade("capBoth", B["ret_in"], RESET, 0.25, 0.3, rest_hidden=False)

# cursor — positions are in the left window's coordinate space
HOME = "translate(250px,250px)"
track("cursor", [
    (0.0, {"transform": HOME}, EASE_IO),
    (A["sel0"], {"transform": "translate(30px,264px)"}, EASE_IO),
    (A["sel1"], {"transform": "translate(378px,270px)"}),
    (SWITCH + 0.6, {"transform": "translate(378px,270px)"}, EASE_IO),
    (B["sel0"], {"transform": "translate(54px,204px)"}, EASE_IO),
    (B["sel1"], {"transform": "translate(400px,210px)"}),
    (RESET - 0.4, {"transform": "translate(400px,210px)"}, EASE_IO),
    (T, {"transform": HOME}),
])

# ───────────────────────── drawing helpers ─────────────────────────
DOTS = "".join(f'<circle cx="{20 + i * 18}" cy="20" r="5.5" fill="{c}"/>'
               for i, c in enumerate(("#ff5f57", "#febc2e", "#28c840")))


def window(x, y, w, h, body, title="", pill="", dark=False, cls=""):
    bg, bar_bg, rule = ("#1f2130", "#292c3f", "#34384f") if dark else ("#fff", "#f7f7f9", "#ececf0")
    head = ""
    if pill:
        head = (f'<rect x="{w / 2 - 110}" y="9" width="220" height="22" rx="11" fill="#f1f1f4"/>'
                f'<text x="{w / 2}" y="24.5" class="t" fill="#8c8c92" font-size="11.5" text-anchor="middle">{pill}</text>')
    if title:
        tab_bg, tab_ink = ("#1f2130", "#c9cce0") if dark else ("#fff", "#444")
        head = (f'<rect x="84" y="8" width="132" height="32" rx="8" fill="{tab_bg}"/>'
                f'<text x="100" y="28.5" class="t" font-size="12.5" fill="{tab_ink}">{title}</text>')
    return f'''
<g transform="translate({x},{y})"><g class="{cls}" style="transform-box:fill-box;transform-origin:50% 50%">
  <rect width="{w}" height="{h}" rx="14" fill="{bg}" filter="url(#winShadow)"/>
  <path d="M0 14a14 14 0 0 1 14-14h{w - 28}a14 14 0 0 1 14 14v26H0z" fill="{bar_bg}"/>
  <rect y="40" width="{w}" height="1" fill="{rule}"/>
  {DOTS}{head}
  {body}
</g></g>'''


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


def new_card(p, y, grad, color, time, thought, quote, source, quote_cls="t", italic=True):
    glow = (f'<rect class="{p}glow" x="-5" y="-5" width="466" height="130" rx="14" fill="none" '
            f'stroke="{color}" stroke-opacity=".45" stroke-width="2" filter="url(#soft)"/>')
    style = ' font-style="italic"' if italic else ""
    block = f'''<rect x="16" y="66" width="2" height="40" rx="1" fill="#000" fill-opacity=".15"/>
    <text x="28" y="81" class="{quote_cls}" font-size="12.5"{style} fill="#77777f">{quote}</text>
    <text x="28" y="100" class="t" font-size="12.5" fill="#77777f">【{source}】</text>'''
    return card(y, 120, grad, color, time, [thought], cls=p + "card", extra=glow, after=block)


def keycap(x, w, inner):
    return f'''
<g transform="translate({x},0)">
  <rect y="4" width="{w}" height="54" rx="12" fill="#d9d9e2"/>
  <rect width="{w}" height="54" rx="12" fill="#fff" stroke="#e3e3ea"/>
  {inner}
</g>'''


def panel(p, x, y, quote, thought, type_w, quote_cls="t"):
    return f'''
<g transform="translate({x},{y})">
  <g class="{p}panel" style="transform-box:fill-box;transform-origin:50% 0">
    <rect width="440" height="96" rx="13" fill="#fff" filter="url(#panelShadow)"/>
    <rect x="12" y="11" width="416" height="27" rx="8" fill="#000" fill-opacity=".04"/>
    <text x="22" y="29" class="{quote_cls}" font-size="11.5" fill="#8c8c92">{quote}</text>
    <g clip-path="url(#inputClip)">
      <text x="17" y="66" class="t" font-size="14" fill="#55555c" textLength="{type_w}"
            lengthAdjust="spacingAndGlyphs">{thought}</text>
      <g class="{p}wipe">
        <rect x="16" y="46" width="{type_w + 46}" height="28" fill="#fff"/>
        <rect class="caret" x="17" y="51" width="1.6" height="19" rx=".8" fill="#6180d9"/>
      </g>
    </g>
    <text class="t {p}placeholder" x="22" y="66" font-size="14" fill="#b9b9c0">{S["placeholder"]}</text>
    <text x="428" y="86" class="t" font-size="10" fill="#b9b9c0" text-anchor="end">↵ save · esc</text>
  </g>
</g>'''


# ───────────────────────── scene ─────────────────────────
QUOTE_A = "Step 3: “Tell us about yourself” — 42% drop-off"
QUOTE_B = "export const TOAST_DURATION = 300; // ms"

funnel = "".join(
    f'<rect x="{32 + i * 62}" y="{222 - h}" width="44" height="{h}" rx="6" fill="{c}"/>'
    f'<rect x="{36 + i * 62}" y="232" width="36" height="6" rx="3" fill="#ececf0"/>'
    for i, (h, c) in enumerate(((76, "#dfe6f7"), (60, "#dfe6f7"), (33, "#f6c1b8"), (28, "#dfe6f7"))))

web_body = f'''
  {bar(32, 70, 210, 13, "#d4d4dc")}
  {bar(32, 98, 430)}{bar(32, 116, 380)}
  {funnel}
  {bar(300, 150, 170)}{bar(300, 170, 150)}{bar(300, 190, 176)}{bar(300, 210, 120)}
  <g transform="translate(28,258)">
    <rect class="aselect" width="350" height="28" rx="5" fill="#6180d9" fill-opacity=".24"
          style="transform-box:fill-box;transform-origin:0 50%"/>
  </g>
  <text x="32" y="277" class="t" font-size="15" fill="#2b2b2f" textLength="342"
        lengthAdjust="spacingAndGlyphs">{QUOTE_A}</text>
  {bar(32, 308, 440)}{bar(32, 326, 300)}{bar(32, 344, 400)}{bar(32, 362, 250)}
'''

# A code editor: syntax-coloured bars, one real line that gets selected.
PURPLE, BLUE, ORANGE, GREEN, GREY = "#c792ea", "#82aaff", "#f78c6c", "#c3e88d", "#676e95"
code_rows = [
    [(0, 46, PURPLE), (54, 120, BLUE), (182, 60, GREY)],
    [],
    [(0, 52, PURPLE), (60, 38, PURPLE), (106, 132, BLUE), (246, 40, ORANGE)],
    [(0, 52, PURPLE), (60, 38, PURPLE), (106, 96, BLUE), (210, 64, GREEN)],
    [],
    None,  # the real line
    [(0, 52, PURPLE), (60, 38, PURPLE), (106, 150, BLUE), (264, 34, ORANGE)],
    [],
    [(0, 52, PURPLE), (60, 66, PURPLE), (134, 108, BLUE), (250, 14, GREY)],
    [(22, 48, PURPLE), (78, 96, BLUE), (182, 120, GREEN)],
    [(22, 48, PURPLE), (78, 140, BLUE)],
    [(0, 14, GREY)],
]
code = []
for i, row in enumerate(code_rows):
    y = 86 + i * 25
    code.append(f'<text x="34" y="{y + 4}" class="m" font-size="11" fill="#4a4f6a" text-anchor="end">{i + 7}</text>')
    if row is None:
        code.append(f'''<g transform="translate(50,{y - 14})">
    <rect class="bselect" width="352" height="25" rx="4" fill="#6180d9" fill-opacity=".5"
          style="transform-box:fill-box;transform-origin:0 50%"/></g>
  <text x="56" y="{y + 4}" class="m" font-size="13.5" textLength="340" lengthAdjust="spacingAndGlyphs"><tspan fill="{PURPLE}">export const</tspan><tspan fill="{BLUE}"> TOAST_DURATION</tspan><tspan fill="#a6accd"> = </tspan><tspan fill="{ORANGE}">300</tspan><tspan fill="#a6accd">;</tspan><tspan fill="{GREY}"> // ms</tspan></text>''')
    else:
        code.extend(f'<rect x="{56 + x}" y="{y - 5}" width="{w}" height="8" rx="4" fill="{c}" opacity=".78"/>' for x, w, c in row)
code_body = "\n  ".join(code)

OPT = '<path d="M17 19h8l10 16h6M31 19h10" fill="none" stroke="#55555c" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
RET = '<path d="M56 18v12a4 4 0 0 1-4 4H28m0 0 7-7m-7 7 7 7" fill="none" stroke="#55555c" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
LETTER_T = '<text x="29" y="35" class="t" font-size="20" font-weight="600" fill="#55555c" text-anchor="middle">T</text>'
hotkey = keycap(-64, 58, OPT) + keycap(6, 58, LETTER_T)
enter = keycap(-42, 84, RET)


def caption(cls, label):
    return f'<text class="{cls}" y="102">{label}</text>'


keys = f'''
<g transform="translate(316,486)">
  <g class="akeys">{hotkey}</g><g class="aret">{enter}</g>
  <g class="bkeys">{hotkey}</g><g class="bret">{enter}</g>
  <g font-size="16" text-anchor="middle" class="t" fill="#6b6b75" font-weight="500">
    {caption("capSelect", S["select"])}{caption("acapPress", S["press"])}{caption("acapType", S["type"])}
    {caption("capSaved", S["saved"])}{caption("capSwitch", S["switch"])}
    {caption("bcapPress", S["press"])}{caption("bcapType", S["type"])}{caption("capBoth", S["both"])}
  </g>
</g>'''

LINK = '<tspan fill="#7a6ad8" text-decoration="underline">mixpanel.com/funnels</tspan>'
notes_body = f'''
  <text x="260" y="70" class="t" font-size="11" fill="#a0a0a8" text-anchor="middle">Eureka / 2026-06-29 / Thoughts</text>
  <text x="32" y="112" class="t" font-size="22" font-weight="700" fill="#1f1f24">Random Thoughts — 2026-06-29</text>
  {card(134, 72, "gBlue", "#6180d9", "09:12", S["card1"])}
  {card(218, 72, "gPurple", "#9e73d1", "10:40", S["card2"])}
  {new_card("a", 302, "gCoral", "#e66b80", "11:03", TA, QUOTE_A, LINK)}
  {new_card("b", 434, "gGreen", "#3f9a85", "11:20", TB, QUOTE_B, "Code", quote_cls="m", italic=False)}
'''

bubble = '''
<g transform="translate(1160,650)">
  <g class="abounce" style="transform-box:fill-box;transform-origin:50% 50%">
  <g class="bbounce" style="transform-box:fill-box;transform-origin:50% 50%">
    <circle r="13" fill="url(#dotBlue)"/>
    <circle class="adot" r="13" fill="url(#dotCoral)"/>
    <circle class="bdot" r="13" fill="url(#dotGreen)"/>
  </g></g>
</g>'''

cursor = '''
<g transform="translate(56,64)"><g class="cursor">
  <path d="M0 0v17l4.6-4.2 3 7 2.6-1.1-3-6.9H13z" fill="#1f1f24" stroke="#fff" stroke-width="1.4" stroke-linejoin="round"/>
</g></g>'''


def grad(id_, a, b, vertical=False):
    x2, y2 = ("0", "1") if vertical else ("1", "1")
    return (f'<linearGradient id="{id_}" x1="0" y1="0" x2="{x2}" y2="{y2}">'
            f'<stop offset="0" stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient>')


css_blocks.append("@keyframes blink{0%,55%{opacity:1}56%,100%{opacity:0}}.caret{animation:blink 1s steps(1) infinite}")
css_blocks.append("@keyframes driftA{from{transform:translate(0,0)}to{transform:translate(60px,40px)}}"
                  "@keyframes driftB{from{transform:translate(0,0)}to{transform:translate(-70px,-30px)}}"
                  ".blobA{animation:driftA 8s ease-in-out infinite alternate}"
                  ".blobB{animation:driftB 8s ease-in-out infinite alternate}")
# Without animation support (or with reduced motion) the base styles show the finished scene:
# the editor on the left, both new cards in the note.
css_blocks.insert(0, ",".join("." + name for name in hidden_at_rest) + "{opacity:0}")
css_blocks.append("@media (prefers-reduced-motion:reduce){*{animation:none!important}}")

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 700" role="img"
     aria-label="{S["aria"]}">
<defs>
  <style>
    .t{{font-family:{FONT}}} .m{{font-family:{MONO}}}
    {"".join(css_blocks)}
  </style>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#fff4ee"/><stop offset=".5" stop-color="#f6f3ff"/><stop offset="1" stop-color="#eef6ff"/>
  </linearGradient>
  {grad("gBlue", "#e9f3fc", "#e6ebfa")}
  {grad("gPurple", "#f7f0fc", "#efe8f9")}
  {grad("gCoral", "#fdf0e8", "#fbe7ea")}
  {grad("gGreen", "#ecf9f2", "#e3f3ef")}
  {grad("dotBlue", "#8cc7f2", "#6180d9", True)}
  {grad("dotCoral", "#f5a673", "#e66b80", True)}
  {grad("dotGreen", "#99e6bf", "#59b39e", True)}
  <filter id="winShadow" x="-10%" y="-10%" width="120%" height="125%">
    <feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#5b5b8a" flood-opacity=".16"/>
  </filter>
  <filter id="panelShadow" x="-15%" y="-40%" width="130%" height="200%">
    <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#2b2b55" flood-opacity=".26"/>
  </filter>
  <filter id="blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="60"/></filter>
  <filter id="soft" x="-10%" y="-20%" width="120%" height="140%"><feGaussianBlur stdDeviation="3"/></filter>
  <clipPath id="inputClip"><rect x="12" y="44" width="416" height="32"/></clipPath>
  <clipPath id="frame"><rect width="1200" height="700" rx="28"/></clipPath>
</defs>
<g clip-path="url(#frame)">
  <rect width="1200" height="700" fill="url(#bg)"/>
  <circle class="blobA" cx="180" cy="120" r="170" fill="#f5a673" opacity=".22" filter="url(#blur)"/>
  <circle class="blobB" cx="1040" cy="560" r="200" fill="#8cc7f2" opacity=".28" filter="url(#blur)"/>
  <circle class="blobA" cx="640" cy="700" r="150" fill="#d9b3f2" opacity=".25" filter="url(#blur)"/>
  {window(56, 64, 520, 392, web_body, pill="mixpanel.com/funnels", cls="winA")}
  {window(56, 64, 520, 392, code_body, title="constants.ts", dark=True, cls="winB")}
  {window(624, 64, 520, 580, notes_body, title="Thoughts")}
  {keys}
  {panel("a", 116, 366, QUOTE_A, TA, WA)}
  {panel("b", 96, 300, QUOTE_B, TB, WB, quote_cls="m")}
  {bubble}
  {cursor}
</g>
</svg>
'''

out = Path(__file__).with_name(S["out"])
out.write_text(svg, encoding="utf-8")
print(f"wrote {out} ({len(svg) / 1024:.1f} KB)")

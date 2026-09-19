#!/usr/bin/env python3
"""Generates the two feature animations used in the README:

    feature-screenshot[.zh-CN].svg   ⌥R → drag a region → one line → card with image
    feature-ask[.zh-CN].svg          select → ⌥T → "/ question" → answer in the panel

Same approach as make_hero.py: pure SVG + CSS keyframes, no scripts.
Run:  python3 assets/make_features.py        (English)
      python3 assets/make_features.py zh     (Chinese)
"""
import sys
from pathlib import Path

LANG = sys.argv[1] if len(sys.argv) > 1 else "en"
SUFFIX = "" if LANG == "en" else ".zh-CN"

EASE_OUT = "cubic-bezier(.2,.8,.2,1)"
EASE_IO = "cubic-bezier(.45,0,.25,1)"
SPRING = "cubic-bezier(.3,1.5,.5,1)"
FONT = ('-apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI","PingFang SC",'
        '"Helvetica Neue",Arial,sans-serif')
W, H = 600, 420


class Anim:
    """Collects @keyframes; every track loops with the same duration so nothing drifts."""

    def __init__(self, T):
        self.T, self.css = T, []

    def track(self, name, frames):
        T = self.T
        frames = sorted(frames, key=lambda f: f[0])
        if frames[0][0] > 0:
            frames.insert(0, (0.0, frames[0][1]))
        if frames[-1][0] < T:
            frames.append((T, frames[-1][1]))
        out = [f"@keyframes {name}{{"]
        for t, props, *rest in frames:
            body = ";".join(f"{k}:{v}" for k, v in props.items())
            if rest and rest[0]:
                body += f";animation-timing-function:{rest[0]}"
            out.append(f"{t / T * 100:.2f}%{{{body}}}")
        out.append("}")
        self.css.append("".join(out) + f".{name}{{animation:{name} {T}s linear infinite}}")

    def fade(self, name, t_in, t_out, d_in=0.3, d_out=0.3):
        self.track(name, [
            (max(t_in - 0.001, 0), {"opacity": 0}, EASE_OUT),
            (t_in + d_in, {"opacity": 1}),
            (t_out, {"opacity": 1}, EASE_IO),
            (t_out + d_out, {"opacity": 0}),
        ])

    def pop(self, name, t_in, t_out, dy=10):
        self.track(name, [
            (t_in - 0.001, {"opacity": 0, "transform": f"translateY({dy}px) scale(.96)"}, EASE_OUT),
            (t_in + 0.3, {"opacity": 1, "transform": "translateY(0) scale(1)"}),
            (t_out, {"opacity": 1, "transform": "translateY(0) scale(1)"}, EASE_IO),
            (t_out + 0.25, {"opacity": 0, "transform": "translateY(-6px) scale(.98)"}),
        ])

    def keypress(self, name, t_in, t_press, t_out):
        self.track(name, [
            (t_in - 0.001, {"opacity": 0, "transform": "translateY(8px)"}, EASE_OUT),
            (t_in + 0.2, {"opacity": 1, "transform": "translateY(0)"}),
            (t_press, {"opacity": 1, "transform": "translateY(0)"}, EASE_OUT),
            (t_press + 0.1, {"opacity": 1, "transform": "translateY(4px)"}),
            (t_press + 0.3, {"opacity": 1, "transform": "translateY(0)"}),
            (t_out, {"opacity": 1, "transform": "translateY(0)"}, EASE_IO),
            (t_out + 0.3, {"opacity": 0, "transform": "translateY(0)"}),
        ])

    def wipe(self, name, t0, t1, width, t_reset):
        self.track(name, [
            (t0, {"transform": "translateX(0)"}),
            (t1, {"transform": f"translateX({width}px)"}),
            (t_reset, {"transform": f"translateX({width}px)"}),
            (t_reset + 0.01, {"transform": "translateX(0)"}),
        ])


# ───────────────────────── shared drawing ─────────────────────────
OPT = ('<path d="M15 17h7l9 14h6M28 17h9" fill="none" stroke="#55555c" stroke-width="2" '
       'stroke-linecap="round" stroke-linejoin="round"/>')
RET = ('<path d="M50 16v10a4 4 0 0 1-4 4H26m0 0 6-6m-6 6 6 6" fill="none" stroke="#55555c" '
       'stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>')
SPARK = ('M6 0 L7.4 4.6 L12 6 L7.4 7.4 L6 12 L4.6 7.4 L0 6 L4.6 4.6 Z '
         'M11.5 0.5 l.6 1.6 1.6 .6 -1.6 .6 -.6 1.6 -.6 -1.6 -1.6 -.6 1.6 -.6 Z')


def keycap(x, w, inner):
    return (f'<g transform="translate({x},0)"><rect y="4" width="{w}" height="48" rx="11" fill="#d9d9e2"/>'
            f'<rect width="{w}" height="48" rx="11" fill="#fff" stroke="#e3e3ea"/>{inner}</g>')


def letter(ch):
    return (f'<text x="26" y="31" class="t" font-size="18" font-weight="600" fill="#55555c" '
            f'text-anchor="middle">{ch}</text>')


def hotkey(cls, ch):
    return f'<g class="{cls}">{keycap(-58, 52, OPT)}{keycap(6, 52, letter(ch))}</g>'


def window(body, pill):
    dots = "".join(f'<circle cx="{18 + i * 16}" cy="18" r="5" fill="{c}"/>'
                   for i, c in enumerate(("#ff5f57", "#febc2e", "#28c840")))
    return f'''
<g transform="translate(30,26)">
  <rect width="540" height="300" rx="13" fill="#fff" filter="url(#winShadow)"/>
  <path d="M0 13a13 13 0 0 1 13-13h514a13 13 0 0 1 13 13v23H0z" fill="#f7f7f9"/>
  <rect y="36" width="540" height="1" fill="#ececf0"/>{dots}
  <rect x="160" y="8" width="220" height="20" rx="10" fill="#f1f1f4"/>
  <text x="270" y="22" class="t" font-size="11" fill="#8c8c92" text-anchor="middle">{pill}</text>
  {body}
</g>'''


def bar(x, y, w, h=8, fill="#e9e9ee"):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{h / 2}" fill="{fill}"/>'


def cursor(cls):
    return (f'<g class="{cls}"><path d="M0 0v17l4.6-4.2 3 7 2.6-1.1-3-6.9H13z" fill="#1f1f24" '
            f'stroke="#fff" stroke-width="1.4" stroke-linejoin="round"/></g>')


def document(anim, body, aria, blobs):
    css = "".join(anim.css)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" role="img" aria-label="{aria}">
<defs>
  <style>.t{{font-family:{FONT}}}{css}
  @keyframes blink{{0%,55%{{opacity:1}}56%,100%{{opacity:0}}}}.caret{{animation:blink 1s steps(1) infinite}}
  @keyframes dot{{0%,60%,100%{{opacity:.25}}30%{{opacity:1}}}}
  .d1{{animation:dot 1.2s infinite}}.d2{{animation:dot 1.2s .2s infinite}}.d3{{animation:dot 1.2s .4s infinite}}
  @media (prefers-reduced-motion:reduce){{*{{animation:none!important}}}}</style>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">{blobs[0]}</linearGradient>
  <linearGradient id="gGreen" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ecf9f2"/><stop offset="1" stop-color="#e3f3ef"/></linearGradient>
  <linearGradient id="chartFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6180d9" stop-opacity=".22"/><stop offset="1" stop-color="#6180d9" stop-opacity="0"/></linearGradient>
  <filter id="winShadow" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#5b5b8a" flood-opacity=".16"/></filter>
  <filter id="panelShadow" x="-15%" y="-30%" width="130%" height="170%"><feDropShadow dx="0" dy="9" stdDeviation="12" flood-color="#2b2b55" flood-opacity=".24"/></filter>
  <filter id="aiShadow" x="-15%" y="-30%" width="130%" height="170%"><feDropShadow dx="0" dy="8" stdDeviation="12" flood-color="#8c5cd9" flood-opacity=".30"/></filter>
  <filter id="blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="45"/></filter>
  <clipPath id="frame"><rect width="{W}" height="{H}" rx="22"/></clipPath>
</defs>
<g clip-path="url(#frame)">
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  {blobs[1]}
  {body}
</g>
</svg>
'''


# ───────────────────────── strings ─────────────────────────
S = {
    "en": dict(
        shot_thought=("spike = the push we sent at 9am", 214),
        shot_placeholder="Add a comment…",
        shot_aria="Eureka screenshot capture: press Option+R, drag a region, type one line, press Enter. "
                  "The screenshot and the comment are saved together as one card.",
        ask_q=("what does p95 mean?", 138),
        ask_answer=["95% of requests finished within 840 ms; the",
                    "slowest 5% took longer. It measures tail latency,",
                    "which is what your unluckiest users feel."],
        ask_aria="Eureka AI quick answer: select text, press Option+T, type a slash and a question. "
                 "The answer appears in the panel, using the selected text as context.",
    ),
    "zh": dict(
        shot_thought=("这个尖峰 = 早上 9 点那条推送", 196),
        shot_placeholder="写一句评论…",
        shot_aria="Eureka 截图捕获：按 Option+R，框选一块区域，写一句话，回车。"
                  "截图和评论会作为同一张卡片保存。",
        ask_q=("p95 是什么意思？", 118),
        ask_answer=["95% 的请求在 840 ms 内完成，最慢的 5% 更久。",
                    "它衡量的是 tail latency，",
                    "也就是最倒霉的那批用户的实际体验。"],
        ask_aria="Eureka AI 快问：选中文字，按 Option+T，输入斜杠和问题。"
                 "答案直接显示在面板里，并以选中的文字为上下文。",
    ),
}[LANG]

# ───────────────────────── scene 1: screenshot ─────────────────────────
CHART_LINE = "M0 78 L40 70 L80 74 L120 60 L160 64 L200 18 L240 52 L280 58 L320 50 L360 56"
CHART = f'''<g id="chart">
  <path d="{CHART_LINE} V96 H0 Z" fill="url(#chartFill)"/>
  <path d="{CHART_LINE}" fill="none" stroke="#6180d9" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round"/>
  <circle cx="200" cy="18" r="4.5" fill="#fff" stroke="#e66b80" stroke-width="2.4"/>
  <path d="M0 96.5H360" stroke="#ececf0"/>
</g>'''


def screenshot_scene():
    a = Anim(9.0)
    KEY_IN, KEY_PRESS, KEY_OUT = 0.3, 0.75, 1.35
    DRAG0, DRAG1 = 1.5, 2.5
    PANEL_IN, TYPE0, TYPE1 = 2.8, 3.4, 5.0
    RET_IN, RET_PRESS, RET_OUT = 5.1, 5.4, 5.95
    PANEL_OUT, CARD_IN, RESET = 5.6, 5.8, 8.4
    text, tw = S["shot_thought"]

    a.keypress("hk", KEY_IN, KEY_PRESS, KEY_OUT)
    a.keypress("ret", RET_IN, RET_PRESS, RET_OUT)
    a.track("cur", [
        (0.0, {"transform": "translate(330px,250px)", "opacity": 1}, EASE_IO),
        (DRAG0, {"transform": "translate(120px,98px)", "opacity": 1}, EASE_IO),
        (DRAG1, {"transform": "translate(440px,238px)", "opacity": 1}),
        (DRAG1 + 0.3, {"transform": "translate(440px,238px)", "opacity": 0}),
        (RESET, {"transform": "translate(330px,250px)", "opacity": 0}, EASE_IO),
        (a.T, {"transform": "translate(330px,250px)", "opacity": 1}),
    ])
    a.track("marquee", [
        (DRAG0 - 0.001, {"transform": "scale(0)", "opacity": 0}),
        (DRAG0, {"transform": "scale(0)", "opacity": 1}, EASE_IO),
        (DRAG1, {"transform": "scale(1)", "opacity": 1}),
        (DRAG1 + 0.15, {"transform": "scale(1)", "opacity": 1}),
        (DRAG1 + 0.4, {"transform": "scale(1)", "opacity": 0}),
    ])
    a.track("flash", [
        (DRAG1 + 0.1, {"opacity": 0}, EASE_OUT),
        (DRAG1 + 0.2, {"opacity": .7}, EASE_IO),
        (DRAG1 + 0.5, {"opacity": 0}),
    ])
    a.pop("panel", PANEL_IN, PANEL_OUT)
    a.fade("ph", PANEL_IN, TYPE0 - 0.05, 0.3, 0.05)
    a.wipe("wipe", TYPE0, TYPE1, tw + 6, PANEL_OUT + 0.3)
    a.track("card", [
        (CARD_IN - 0.001, {"opacity": 0, "transform": "translateY(20px) scale(.97)"}, SPRING),
        (CARD_IN + 0.55, {"opacity": 1, "transform": "translateY(0) scale(1)"}),
        (RESET, {"opacity": 1, "transform": "translateY(0) scale(1)"}, EASE_IO),
        (RESET + 0.4, {"opacity": 0, "transform": "translateY(0) scale(1)"}),
    ])
    a.css.append(".hk,.ret,.panel,.ph,.marquee,.flash,.cur{opacity:0}")

    tiles = "".join(
        f'<g transform="translate({28 + i * 124},54)"><rect width="112" height="46" rx="9" fill="#f6f6f9"/>'
        f'{bar(12, 12, 46, 6, "#dcdce4")}{bar(12, 27, w, 9, c)}</g>'
        for i, (w, c) in enumerate(((60, "#c9d3f2"), (74, "#c9d3f2"), (52, "#f6c1b8"), (66, "#c9d3f2"))))
    body = f'''{tiles}
  <g transform="translate(90,124)">{CHART}</g>
  {bar(90, 240, 300)}{bar(90, 256, 230)}{bar(90, 272, 270)}'''

    thumb = '''<rect width="416" height="112" rx="8" fill="#f6f6f9"/>
    <g transform="translate(58,10) scale(.84)"><use href="#chart"/></g>'''

    scene = f'''
  {window(body, "analytics.app/dashboard")}
  <g transform="translate(108,120)">
    <rect class="flash" width="332" height="140" rx="4" fill="#fff"/>
    <rect class="marquee" width="332" height="140" rx="4" fill="#6180d9" fill-opacity=".12"
          stroke="#6180d9" stroke-width="1.5" stroke-dasharray="6 4"
          style="transform-box:fill-box;transform-origin:0 0"/>
  </g>
  <g transform="translate(80,118)"><g class="panel" style="transform-box:fill-box;transform-origin:50% 0">
    <rect width="440" height="190" rx="13" fill="#fff" filter="url(#panelShadow)"/>
    <g transform="translate(12,12)">{thumb}</g>
    <clipPath id="in1"><rect x="12" y="138" width="416" height="30"/></clipPath>
    <g clip-path="url(#in1)">
      <text x="17" y="159" class="t" font-size="14" fill="#55555c" textLength="{tw}" lengthAdjust="spacingAndGlyphs">{text}</text>
      <g class="wipe"><rect x="16" y="140" width="420" height="28" fill="#fff"/>
        <rect class="caret" x="17" y="144" width="1.6" height="19" rx=".8" fill="#6180d9"/></g>
    </g>
    <text class="t ph" x="22" y="159" font-size="14" fill="#b9b9c0">{S["shot_placeholder"]}</text>
    <text x="428" y="180" class="t" font-size="10" fill="#b9b9c0" text-anchor="end">↵ save · esc</text>
  </g></g>
  <g transform="translate(80,96)"><g class="card" style="transform-box:fill-box;transform-origin:50% 50%">
    <rect width="440" height="214" rx="12" fill="#fff" filter="url(#panelShadow)"/>
    <rect width="440" height="214" rx="12" fill="url(#gGreen)"/>
    <path d="{SPARK}" transform="translate(16,14)" fill="#59b39e" opacity=".75"/>
    <text x="35" y="25" class="t" font-size="11.5" fill="#3f9a85">14:22</text>
    <text x="16" y="52" class="t" font-size="14" fill="#2b2b2f">{text}</text>
    <g transform="translate(12,66)"><rect width="416" height="136" rx="8" fill="#fff"/>
      <g transform="translate(28,14) scale(1)"><use href="#chart"/></g></g>
  </g></g>
  <g transform="translate(300,346)">{hotkey("hk", "R")}<g class="ret">{keycap(-38, 76, RET)}</g></g>
  <g transform="translate(30,26)">{cursor("cur")}</g>'''
    blobs = ('<stop offset="0" stop-color="#eefaf4"/><stop offset=".55" stop-color="#f3f6ff"/><stop offset="1" stop-color="#f7f1ff"/>',
             '<circle cx="90" cy="60" r="110" fill="#99e6bf" opacity=".28" filter="url(#blur)"/>'
             '<circle cx="540" cy="380" r="120" fill="#8cc7f2" opacity=".26" filter="url(#blur)"/>')
    return document(a, scene, S["shot_aria"], blobs)


# ───────────────────────── scene 2: ask AI ─────────────────────────
def ask_scene():
    a = Anim(10.0)
    SEL0, SEL1 = 0.5, 1.2
    KEY_IN, KEY_PRESS, KEY_OUT = 1.3, 1.65, 2.2
    PANEL_IN, TYPE0, TYPE1 = 1.9, 2.5, 3.7
    RET_IN, RET_PRESS, RET_OUT = 3.8, 4.0, 4.2
    ASK, ANSWER, RESET = 4.45, 5.2, 9.4
    LINE = 0.75
    q, qw = S["ask_q"]
    quote = "p95 latency rose to 840 ms after the deploy"
    AI = "#8c5cd9"

    a.track("cur", [
        (0.0, {"transform": "translate(300px,230px)"}, EASE_IO),
        (SEL0, {"transform": "translate(26px,150px)"}, EASE_IO),
        (SEL1, {"transform": "translate(352px,156px)"}),
        (RESET - 0.3, {"transform": "translate(352px,156px)"}, EASE_IO),
        (a.T, {"transform": "translate(300px,230px)"}),
    ])
    a.track("sel", [
        (SEL0, {"transform": "scaleX(0)", "opacity": 1}, EASE_IO),
        (SEL1, {"transform": "scaleX(1)", "opacity": 1}),
        (RESET, {"transform": "scaleX(1)", "opacity": 1}),
        (RESET + 0.4, {"transform": "scaleX(1)", "opacity": 0}),
        (a.T, {"transform": "scaleX(0)", "opacity": 0}),
    ])
    a.keypress("hk", KEY_IN, KEY_PRESS, KEY_OUT)
    a.keypress("ret", RET_IN, RET_PRESS, RET_OUT)
    a.pop("panel", PANEL_IN, RESET)
    a.fade("ph", PANEL_IN, TYPE0 - 0.05, 0.3, 0.05)
    a.fade("aiRing", TYPE0, ASK + 0.1, 0.25, 0.2)       # purple border once "/" is typed
    a.fade("hintSave", PANEL_IN, TYPE0, 0.3, 0.1)
    a.fade("hintAsk", TYPE0 + 0.1, ASK, 0.2, 0.1)
    a.fade("hintEsc", ANSWER, RESET, 0.3, 0.2)
    a.wipe("wipe", TYPE0, TYPE1, qw + 22, RESET + 0.3)
    a.track("caretBox", [(0, {"opacity": 1}), (ASK, {"opacity": 1}), (ASK + 0.01, {"opacity": 0}),
                         (RESET + 0.3, {"opacity": 0}), (RESET + 0.31, {"opacity": 1})])
    a.fade("dots", ASK + 0.25, ANSWER - 0.15, 0.2, 0.15)
    a.track("grow", [
        (ASK - 0.05, {"opacity": 0, "transform": "scaleY(.5)"}, EASE_OUT),
        (ASK + 0.35, {"opacity": 1, "transform": "scaleY(1)"}),
        (RESET, {"opacity": 1, "transform": "scaleY(1)"}),
        (RESET + 0.25, {"opacity": 0, "transform": "scaleY(1)"}),
    ])
    a.fade("sep", ANSWER, RESET, 0.3, 0.2)
    for i in range(3):
        a.wipe(f"a{i}", ANSWER + 0.15 + i * LINE, ANSWER + 0.15 + (i + 1) * LINE, 420, RESET + 0.3)
    a.css.append(".hk,.ret,.panel,.ph,.aiRing,.hintSave,.hintAsk,.hintEsc,.dots,.grow,.sep{opacity:0}")

    body = f'''
  {bar(28, 62, 190, 12, "#d4d4dc")}
  {bar(28, 92, 470)}{bar(28, 108, 420)}{bar(28, 124, 450)}
  <g transform="translate(24,142)"><rect class="sel" width="332" height="26" rx="5" fill="#6180d9" fill-opacity=".24"
      style="transform-box:fill-box;transform-origin:0 50%"/></g>
  <text x="28" y="160" class="t" font-size="14.5" fill="#2b2b2f" textLength="324" lengthAdjust="spacingAndGlyphs">{quote}</text>
  {bar(28, 186, 460)}{bar(28, 202, 380)}{bar(28, 218, 430)}{bar(28, 234, 300)}{bar(28, 262, 440)}{bar(28, 278, 210)}'''

    answer = "".join(
        f'<text x="17" y="{122 + i * 21}" class="t" font-size="13.5" fill="#3d3d44">{line}</text>'
        f'<g class="a{i}"><rect x="14" y="{106 + i * 21}" width="424" height="22" fill="#fff"/></g>'
        for i, line in enumerate(S["ask_answer"]))

    scene = f'''
  {window(body, "status.acme.dev/incident-42")}
  <g transform="translate(80,204)"><g class="panel" style="transform-box:fill-box;transform-origin:50% 0">
    <g class="grow" style="transform-box:fill-box;transform-origin:50% 0">
      <rect width="440" height="190" rx="13" fill="#fff" filter="url(#aiShadow)"/>
    </g>
    <rect width="440" height="92" rx="13" fill="#fff" filter="url(#panelShadow)"/>
    <rect class="aiRing" x=".75" y=".75" width="438.5" height="90.5" rx="12.5" fill="none" stroke="{AI}" stroke-opacity=".38" stroke-width="1.5"/>
    <g class="grow" style="transform-box:fill-box;transform-origin:50% 0">
      <rect y="60" width="440" height="116" fill="#fff"/>
      <rect x=".75" y=".75" width="438.5" height="188.5" rx="12.5" fill="none" stroke="{AI}" stroke-opacity=".38" stroke-width="1.5"/>
    </g>
    <rect x="12" y="11" width="416" height="26" rx="8" fill="#000" fill-opacity=".04"/>
    <text x="22" y="28.5" class="t" font-size="11.5" fill="#8c8c92">{quote}</text>
    <clipPath id="in2"><rect x="12" y="44" width="416" height="32"/></clipPath>
    <g clip-path="url(#in2)">
      <text x="17" y="66" class="t" font-size="14" fill="{AI}"><tspan font-weight="700">/</tspan><tspan dx="7" textLength="{qw}" lengthAdjust="spacingAndGlyphs">{q}</tspan></text>
      <g class="wipe"><rect x="16" y="46" width="420" height="28" fill="#fff"/>
        <g class="caretBox"><rect class="caret" x="17" y="51" width="1.6" height="19" rx=".8" fill="{AI}"/></g></g>
    </g>
    <text class="t ph" x="22" y="66" font-size="14" fill="#b9b9c0">Jot a thought… or / to ask AI</text>
    <g class="dots" fill="{AI}"><circle class="d1" cx="22" cy="104" r="2.6"/><circle class="d2" cx="32" cy="104" r="2.6"/><circle class="d3" cx="42" cy="104" r="2.6"/></g>
    <rect class="sep" x="16" y="88" width="408" height="1" fill="#000" fill-opacity=".07"/>
    <clipPath id="in3"><rect x="12" y="98" width="416" height="74"/></clipPath>
    <g class="sep" clip-path="url(#in3)">{answer}</g>
    <text class="t hintSave" x="428" y="84" font-size="10" fill="#b9b9c0" text-anchor="end">↵ save · esc</text>
    <text class="t hintAsk" x="428" y="84" font-size="10" fill="{AI}" text-anchor="end">↵ ask AI · esc</text>
    <text class="t hintEsc" x="428" y="180" font-size="10" fill="#b9b9c0" text-anchor="end">esc</text>
  </g></g>
  <g transform="translate(300,346)">{hotkey("hk", "T")}<g class="ret">{keycap(-38, 76, RET)}</g></g>
  <g transform="translate(30,26)">{cursor("cur")}</g>'''
    blobs = ('<stop offset="0" stop-color="#f8f1ff"/><stop offset=".55" stop-color="#f4f4ff"/><stop offset="1" stop-color="#fff3f0"/>',
             '<circle cx="520" cy="70" r="120" fill="#d9b3f2" opacity=".32" filter="url(#blur)"/>'
             '<circle cx="70" cy="380" r="110" fill="#f5a673" opacity=".2" filter="url(#blur)"/>')
    return document(a, scene, S["ask_aria"], blobs)


here = Path(__file__).parent
for name, svg in (("feature-screenshot", screenshot_scene()), ("feature-ask", ask_scene())):
    out = here / f"{name}{SUFFIX}.svg"
    out.write_text(svg, encoding="utf-8")
    print(f"wrote {out.name} ({len(svg) / 1024:.1f} KB)")

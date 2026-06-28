# TripAnnouncementViewV2 — Complete Specification & Flutter Port Plan

> **Purpose.** This is the exhaustive, value-for-value documentation of everything `TripAnnouncementViewV2.swift` (and its dependencies) does, written so it can be re-implemented in Flutter **without changing a single value**. Every number, color, duration, delay, font weight/size, dimension, and animation curve below is copied verbatim from the Swift source. The Flutter plan at the end maps each Swift mechanism to its Flutter equivalent.
>
> **Scope.** Only `TripAnnouncementViewV2` and the code it uses:
> - `TripAnnouncementViewV2.swift` (the screen)
> - `DesignTokens.swift` (colors + fonts it references)
> - `LoopingVideoView.swift` (coin video)
> - `Haptics.swift` (haptic feedback)
> - `CardWarpShader.metal` (card entrance distortion)
> - Assets: `ScapiaCoin.mp4`, `PillCoin`, `FlightPlane`, `EmiratesLogo`, `CalendarIcon`, `ArrowRight`, `BoltFill`, `StayHut`, font `LexendDeca-VF.ttf`
> - V1 (`TripAnnouncementView.swift`), Rive, RewardStack, etc. are **out of scope**.

---

## 0. High-level summary

`TripAnnouncementViewV2` is a single screen that plays a **three-phase, fully-timed, non-interactive animation sequence** after a flight booking:

1. **`earned`** — Orange gradient screen. A Scapia coin video plays once (morphs into an energy bolt). The number **32,800** rolls into place ticker-style under the label "Travel rewards earned".
2. **`added`** — The number **disintegrates into particles** (Apple-Wallet style), shaped from the actual glyph pixels, that stream up into a **balance pill** at the top. The pill springs in at 0 and counts up to **5,790**. The heading "Instantly added to your balance" wipes in left→right. A glassy shine sweeps the pill border.
3. **`trip`** — Crossfade to the booked-flight card ("London to Delhi") which flies in with a Metal warp distortion. Below it: a subtitle and a hotel offer card with a live countdown.

The whole sequence is driven by one `async` function `runSequence()` started via `.task`. There is **no user interaction** — it's a timed cinematic.

The root view is a `ZStack` of two screens, crossfaded by opacity on `phase`:
```swift
ZStack {
    rewardsScreen.opacity(phase == .trip ? 0 : 1)   // phases earned + added
    tripScreen.opacity(phase == .trip ? 1 : 0)       // phase trip
}
.task { await runSequence() }
.onReceive(timer) { _ in if secondsLeft > 0 { secondsLeft -= 1 } }
```

---

## 1. State variables (initial values)

| Variable | Type | Initial | Meaning |
|---|---|---|---|
| `phase` | enum `{earned, added, trip}` | `.earned` | Current sequence phase |
| `appeared` | Bool | `false` | First fade/scale-in of the earned screen |
| `rollEarned` | Bool | `false` | Triggers the earned ticker roll |
| `numberShown` | Bool | `true` | Earned number visible until it dissolves |
| `balanceCount` | Int | `0` | Top balance pill value (counts to 5,790) |
| `pillShown` | Bool | `false` | Balance pill springs in |
| `headingReveal` | CGFloat | `0` | "Instantly added" left→right wipe progress (0→1) |
| `shineActive` | Bool | `false` | Border shine runs |
| `shineAngle` | Double | `0` | Angular gradient rotation (→360) |
| `pillPulse` | CGFloat | `1` | Gentle scale pulse during shine |
| `dissolveDots` | `[DissolveDot]` | `[]` | Particle list |
| `dissolveStart` | `Date?` | `nil` | Moment disintegration began |
| `dissolveProgress` | CGFloat | `0` | Mask sweep 0→1 (bottom→top) |
| `bandTop` | CGFloat | `-40` | Glyph-pixel band top (rel. to centre); overwritten by sampler |
| `bandBottom` | CGFloat | `40` | Glyph-pixel band bottom; overwritten by sampler |
| `textLiftEnabled` | let Bool | `true` | Enables the anticipation lift on the number |
| `numberZoom` | CGFloat | `1` | Number scale (→1.06) |
| `numberLift` | CGFloat | `0` | Number upward drift (→ -28) |
| `entranceTrigger` | Int | `0` | Fires the trip-card keyframe entrance (→1) |
| `headingShown` | Bool | `false` | Trip-screen heading fade-in |
| `bodyShown` | Bool | `false` | Trip-screen subtitle + offer fade-in |
| `secondsLeft` | Int | `24*3600 + 32*60 + 27` = **88,347** | Offer countdown (24:32:27) |

### Sequence constants
| Constant | Value | Meaning |
|---|---|---|
| `dissolveWaveStart` | `0.18` (s) | Crossfade beat before the dissolve wave climbs |
| `dissolveWaveSpread` | `0.95` (s) | Duration of the wave climbing the text |
| `cardW` | `326` | Trip card width |
| `cardH` | `401` | Trip card height |

---

## 2. Colors (exact)

### Local to V2 (defined inside the struct)
| Name | Hex / definition | RGB (0–255) |
|---|---|---|
| `bgTop` | `#FFF8EE` | (255, 248, 238) |
| `bgBottom` | `#F7F9F4` | (247, 249, 244) |
| `detailBG` | `#F8FAF5` | (248, 250, 245) |
| `imageBG` | `#FEF8E9` | (254, 248, 233) |
| `navy` | `#031223` | (3, 18, 35) |
| `green` | `#389E0D` | (56, 158, 13) |
| `offerBG` | `#F9F7D1` | (249, 247, 209) |
| `closeBG` | `#E9EBE7` | (233, 235, 231) |
| `balanceInk` | `#141C20` | (20, 28, 32) |
| `cardMint` | `#BDE3DF` | (189, 227, 223) |
| `alertAmber` | `#D48806` | (212, 136, 6) |
| `rewardsBgTop` | `#EF6004` | (239, 96, 4) |
| `rewardsTextWhite` | `Color.white.opacity(0.88)` | white @ 88% |
| `rewardsLabel` | `#FFFBE6` | (255, 251, 230) |

### Referenced from `DesignColors` (DesignTokens.swift)
| Name | Hex | RGB |
|---|---|---|
| `tripCardGradientBottom` | `#FDD910` | (253, 217, 16) |
| `rewardsGradientTop` | `#E96307` | (233, 99, 7) |
| `textHighEmphasis` | `#262B30` | (38, 43, 48) |

> All other `DesignColors` members exist but are **not** used by V2.

---

## 3. Fonts (Lexend Deca)

Loaded from `LexendDeca-VF.ttf` (variable font), addressed by PostScript instance name (NOT via `.weight()` — that silently fails on the registered VF). Helpers in `DesignFont`:

| Helper | PostScript name |
|---|---|
| `DesignFont.regular(size)` | `LexendDeca-Regular` |
| `DesignFont.medium(size)` | `LexendDeca-Medium` |
| `DesignFont.semibold(size)` | `LexendDeca-SemiBold` |
| `DesignFont.bold(size)` | `LexendDeca-Bold` |
| `DesignFont.extraBold(size)` | `LexendDeca-ExtraBold` |
| `DesignFont.black(size)` | `LexendDeca-Black` |

**Flutter:** declare all six weights of Lexend Deca as separate `fontFamily`/`fontWeight` entries OR (safer, matching Swift's approach) register six named families. Map: Regular→w400, Medium→w500, SemiBold→w600, Bold→w700, ExtraBold→w800, Black→w900. **Do not** rely on synthetic weight — embed the actual instances.

---

## 4. The master timeline (`runSequence`)

All sleeps are exact. Cumulative times (`t=`) assume zero execution overhead — they are the design intent. **Reproduce every duration and curve exactly.**

| t (s) | Action | Animation / curve | Values |
|---|---|---|---|
| 0.00 | start; `sleep 200ms` | — | — |
| 0.20 | `appeared = true` | spring | `response: 0.5, dampingFraction: 0.82` |
| 0.20 | `rollEarned = true` | (digit springs, see §5) | — |
| 0.20 | `Haptics.tickerBurst()` | 11 medium impacts, intensity 0.85, over 1.15s | see §8 |
| 0.20 | `sleep 1600ms` | — | let roll settle |
| 1.80 | `sleep 300ms` | — | brief hold |
| 2.10 | `phase = .added` | easeInOut | `duration: 0.45` |
| 2.10 | `numberZoom = 1.06`, `numberLift = -28` (if `textLiftEnabled`) | easeOut | `duration: 1.1` |
| 2.10 | `sleep 120ms` | — | — |
| 2.22 | `dissolveDots = makeDissolveDots()` | (builds particles, §6) | — |
| 2.22 | `dissolveStart = Date()` | — | — |
| 2.22 | `Haptics.startContinuousLow()` | continuous rumble | intensity 0.32, sharpness 0.18, dur 30 |
| 2.22 | **Task A:** `sleep dissolveWaveStart (0.18s)` then `dissolveProgress = 1` | linear | `duration: 0.95` (= `dissolveWaveSpread`) |
| 2.22 | **Task B:** `sleep 300ms` → `pillShown = true` | spring | `response: 0.42, dampingFraction: 0.56` |
| (B) 2.52 | (pill shown) then `sleep 260ms` | — | show 0 for a beat |
| (B) 2.78 | `stepCount(to: 5_790, steps: 46, stepNs: 32_000_000)` → `balanceCount` | stepwise, 46 steps × 32ms ≈ 1.472s | target 5,790 |
| 2.22 | main: `sleep 1200ms` | — | — |
| 3.42 | `headingReveal = 1` | easeInOut | `duration: 1.2` |
| 3.42 | `sleep 1200ms` | — | — |
| 4.62 | `Haptics.stopContinuous()` | — | — |
| 4.62 | `shineActive = true` | — | — |
| 4.62 | `shineAngle = 360` | linear, **repeatForever (no autoreverse)** | `duration: 1.9` |
| 4.62 | `pillPulse = 1.07` | easeOut | `duration: 0.28` |
| 4.62 | `sleep 280ms` | — | — |
| 4.90 | `pillPulse = 1.0` | easeInOut | `duration: 0.5` |
| 4.90 | `sleep 2700ms` | — | — |
| 7.60 | `phase = .trip` (crossfade) | easeInOut | `duration: 0.55` |
| 7.60 | `sleep 120ms` | — | — |
| 7.72 | `entranceTrigger = 1` (fires card entrance §7) | keyframes, total 1.0s | — |
| 7.72 | `sleep 550ms` | — | — |
| 8.27 | `headingShown = true` | easeOut | `duration: 0.4` |
| 8.27 | `sleep 250ms` | — | — |
| 8.52 | `bodyShown = true` | easeOut | `duration: 0.45` |

**Independent timer:** a `Timer.publish(every: 1s)` decrements `secondsLeft` by 1 each second while `> 0` (drives the offer countdown), running for the whole screen lifetime.

### `stepCount` helper
```
stepCount(from: 0, to: target, steps: N, stepNs: ns, set:)
for i in 0...N:  set(start + (target-start)*i/N); sleep(stepNs)
set(target)  // ensure exact final
```
For the balance: `from 0, to 5790, steps 46, stepNs 32_000_000` → 47 assignments (i = 0…46), each value = `5790 * i / 46` (integer division), 32 ms apart, then exact 5790.

---

## 5. Rolling ticker number (earned amount = 32,800)

`RollingNumberView(value: 32_800, roll: rollEarned, font: DesignFont.black(64), color: rewardsTextWhite)`

- Formats the int with `,` grouping → string `"32,800"`, split into characters.
- Layout = horizontal `HStack(spacing: 0)`, `.fixedSize()`.
- **Digit cell:** `digitWidth = 41`, `digitHeight = 78`.
- **Comma cell:** `commaWidth = 20`, height `78`, centered, rendered as plain `Text`.
- Each digit is a `RollingDigit`:
  - A vertical `VStack(spacing: 0)` of **20 rows**, each `Text("\(i % 10)")` for `i in 0..<20`, each cell `width × height` = `41 × 78`.
  - Offset: `roll ? -CGFloat(10 + digit) * height : 0` — i.e. rests on row 0 ("0"), then rolls to row `(10 + digit)` (a full extra spin before landing on the target digit).
  - Clipped to `41 × 78`, top-aligned.
  - Animation: `.spring(response: 1.0, dampingFraction: 0.82).delay(delay)` where `delay = Double(idx) * 0.07` (idx = character index in `"32,800"`, so per-character stagger of 0.07s — note the comma also consumes an index).

So digits "3","2",",","8","0","0" get delays 0, 0.07, 0.14, 0.21, 0.28, 0.35 (the comma's delay slot is consumed even though it doesn't roll).

---

## 6. Particle disintegration (the core effect)

### 6a. `makeDissolveDots()` — building the particle cloud

Source text: `"32,800"`. Per-char widths: digit `41`, comma `20`. `fontSize = 64`. Total width = 41+41+20+41+41+41 = **225**.

**Pass 1 — glyph pixel origins** (centered on the number):
- `x` starts at `-total/2 = -112.5`.
- For each char, cell center `cx = x + cw/2`. Sample glyph pixels via `GlyphSampler.points`:
  - `fontName: "LexendDeca-Black"`, `fontSize: 64`.
  - `maxCount: 180` for comma, else `1020`.
- Each sampled point `p` → origin `(cx + p.x, p.y)`. Advance `x += cw`.

**`GlyphSampler.points`** (rasterize a glyph to pixel centers):
1. `UIFont(name:size:)` (fallback system black).
2. Draw white glyph on black in a grayscale `CGContext`, scale = `2`, padded `ceil(size)+4` each dimension.
3. Flip vertically to upright; draw at `(2,2)`.
4. Step size `step = max(2, Int(sqrt(w*h*0.35 / maxCount)))`.
5. Walk the buffer in `step` increments; any pixel with gray `> 110` → point `(x/scale - width/2, y/scale - height/2)` (relative to glyph center).

**Pass 2 — origins → particles.** Compute `minY/maxY` of all origins, `span = max(1, maxY-minY)`. Set `bandTop = minY`, `bandBottom = maxY`. Then for each origin, generate **3** candidate particles (`0..<3`), each:
- **Drop 20%:** `if Double.random(0...1) < 0.2 { return nil }`.
- Jitter: `jx, jy ∈ random(-2.5...2.5)`.
- `frac = (maxY - o.y) / span` → 0 = bottom row, 1 = top row.
- `ang ∈ random(0 ..< 2π)` (orbit base angle on halo ellipse).
- `rr ∈ random(0...14)` (tight band hugging pill).
- Halo radii: `a = 82`, `b = 32`. → `orbitA = a + rr`, `orbitB = b + rr`.
- `orbitSpeed ∈ random(0.1...0.22)` (rad/s, slow drift around pill).
- `settles = (random(0...1) < 0.034)` — ~3.4% stay as the halo, rest fade.
- `arc = (o.x >= 0 ? 1 : -1) * random(30...85) + random(-10...10)` — sideways bow direction depends on which half of the number.
- `size ∈ random(2.0...4.0)`.
- `gold = (random(0...1) < 0.7)` — 70% gold, 30% white.
- `delay = dissolveWaveStart(0.18) + frac * dissolveWaveSpread(0.95) + random(0...0.04)` — birth time tracks the sweep line climbing bottom→top.
- `dur ∈ random(0.95...1.5)` (travel duration).
- `jamp ∈ random(1.5...4.5)` (settle jitter amplitude).
- `jfreq ∈ random(1.4...2.8)`.
- `jphase ∈ random(0 ..< 2π)`.
- `twFreq ∈ random(2.0...4.0)` (twinkle frequency).
- `twPhase ∈ random(0 ..< 2π)`.

> **Important for the port:** the particle cloud is **shaped from the real rasterized glyphs of "32,800"** at Lexend Deca Black 64pt. The Flutter port must rasterize the same text/font/size and sample pixels the same way (gray > 110, the same `step` formula) to get a visually identical cloud. Randomness uses uniform distributions in the exact ranges above; the *specific* random seed need not match (it's noise), but **all ranges, probabilities (0.2 drop, 0.034 settle, 0.7 gold), counts (×3), and the 64pt/Black glyph source must match exactly.**

### 6b. `DissolveDot` fields
`origin(CGPoint)`, `orbitAngle`, `orbitA`, `orbitB`, `orbitSpeed`, `settles(Bool)`, `arc`, `size`, `gold(Bool)`, `delay`, `dur`, `jamp`, `jfreq`, `jphase`, `twFreq`, `twPhase`.

### 6c. `ParticleDissolveView` — per-frame rendering
Driven by `TimelineView(.animation)` + `Canvas`. Inputs: `dots`, `center` (= number center), `target` (= pill center), `start` (Date), `white = Color.white`, `gold = alertAmber (#D48806)`.

Each frame, `t = now - start`. For each dot:
- `life = t - d.delay`; if `life <= 0` skip (not born — solid masked text still covers it).
- `prog = min(life / d.dur, 1)`.
- Start point `(sx, sy) = center + d.origin`.
- Orbiting settle point: `oa = d.orbitAngle + d.orbitSpeed * t`; `gx = target.x + cos(oa)*d.orbitA`; `gy = target.y + sin(oa)*d.orbitB`.
- **If `prog < 1` (travelling):**
  - Ease `e = 1 - pow(1 - prog, 3)` (cubic ease-out).
  - `x = sx + (gx - sx)*e + d.arc * sin(prog * π)` (bow out then converge).
  - `y = sy + (gy - sy)*e`.
  - `bornOp = min(life / 0.1, 1)` (0.1s fade-in at birth).
  - `arriveFade = d.settles ? 1.0 : (prog < 0.65 ? 1.0 : max(0, 1 - (prog - 0.65)/0.35))` (non-settlers fade out over last 35% of travel).
  - `op = bornOp * arriveFade`.
  - `r = d.size * (1 - 0.2*prog)` (shrinks up to 20%).
- **If `prog >= 1` (settled):**
  - If `!d.settles`: skip (absorbed, gone).
  - `st = life - d.dur`.
  - `x = gx + sin(t*d.jfreq + d.jphase) * d.jamp`.
  - `y = gy + cos(t*d.jfreq*1.2 + d.jphase) * d.jamp`.
  - `twinkle = 0.5 + 0.5*sin(t*d.twFreq + d.twPhase)`.
  - `settleIn = min(st / 0.25, 1)`.
  - `op = (1 - settleIn) + settleIn * (0.4 * (0.7 + 0.3*twinkle))` (eases to ~40% with twinkle).
  - `r = d.size * 0.85`.
- If `op <= 0.02` skip. Else fill an **ellipse** at `(x - r/2, y - r/2, r, r)` with color `(gold ? gold : white).opacity(op)`.

### 6d. The number sweep mask (solid text "eaten" bottom→top)
In `rewardsScreen`, inside the `GeometryReader`:
- `numBoxH = 78`.
- `lineFull = numBoxH/2 + bandBottom`.
- `lineEnd = numBoxH/2 + bandTop - 3`.
- `numberMaskH = dissolveStart == nil ? numBoxH : max(0, lineFull - dissolveProgress * (lineFull - lineEnd))`.
- The number is masked by a top-aligned `Rectangle` of height `numberMaskH` (full width). As `dissolveProgress` goes 0→1 (linear 0.95s), the visible window shrinks from the bottom up, "eating" the text in lockstep with particle births.

---

## 7. Trip-card warp-in entrance (`EntranceEffect`)

A `keyframeAnimator` keyed on `entranceTrigger` (fires when set to 1). Initial `EntranceState`: `offsetY: 600, scale: 0.2, rotation: -45, warp: 1, opacity: 0`.

**Render each frame:**
- If `warp > 0.001`: apply the Metal distortion `cardWarp(.float2(w, h), .float(warp))` with `maxSampleOffset = (32, 0)`; else identity.
- `.scaleEffect(scale, anchor: .bottom)`
- `.rotation3DEffect(.degrees(rotation), axis: (1,0,0), anchor: .bottom, perspective: 1.0)` (X-axis tilt)
- `.offset(y: offsetY)`
- `.opacity(opacity)`

**Keyframe tracks (w/h = cardW 326, cardH 401):**
| Track | Keyframes (value, duration) | Type |
|---|---|---|
| `offsetY` | (-30, 0.55), (0, 0.45) | Cubic |
| `scale` | (0.8, 0.55), (1.0, 0.45) | Cubic |
| `rotation` | (0, 0.9) | Cubic |
| `warp` | (0.2, 0.55), (0, 0.45) | Cubic |
| `opacity` | (1, 0.3) | Linear |

> Note: tracks start from the `EntranceState` initial values and animate **to** the keyframe values. Total entrance ≈ 1.0s. So e.g. `offsetY` goes 600 → -30 (over 0.55) → 0 (over 0.45); `scale` 0.2 → 0.8 → 1.0; `rotation` -45 → 0 (over 0.9); `warp` 1 → 0.2 → 0; `opacity` 0 → 1 (over 0.3).

### `cardWarp` Metal shader
```
ny  = position.y / size.y            // 0 top, 1 bottom
bow = cos(ny * 1.5707963)            // 1 at top, 0 at bottom (π/2)
maxShift = 28.0
xShift = amount * bow * maxShift
return (position.x - xShift, position.y)
```
Bottom-anchored horizontal bow: top edge bends left by up to 28pt at `amount=1`, bottom edge unaffected. **Flutter:** reproduce with a `FragmentProgram` (Flutter GLSL shader) or a custom mesh/`ImageFiltered` warp. A GLSL fragment shader sampling the card texture with the same `xShift` is the faithful route.

---

## 8. Haptics

| Method | Behavior | Exact values |
|---|---|---|
| `tickerBurst(count: 11, over: 1.15)` | Loop of `UIImpactFeedbackGenerator(.medium)`, `impactOccurred(intensity: 0.85)`, interval `max(0.04, 1.15/11) ≈ 0.1045s` between, 11 times | count 11, intensity 0.85, span 1.15s |
| `startContinuousLow()` | CoreHaptics continuous event | intensity `0.32`, sharpness `0.18`, relativeTime 0, duration `30` |
| `stopContinuous()` | Stops the continuous player | — |

Fired at: `tickerBurst()` at t=0.20; `startContinuousLow()` at t=2.22; `stopContinuous()` at t=4.62.

**Flutter:** use `HapticFeedback.mediumImpact()` in a timed loop (Flutter can't set intensity, so this is approximate), and for the continuous rumble use a plugin (e.g. `haptic_feedback` / platform channel to CoreHaptics) or accept a fallback. Haptics are device-only and the *least* critical to value-match, but documented for completeness.

---

## 9. Coin video (`LoopingVideoView`)

Usage in `rewardsScreen`:
```swift
LoopingVideoView(resource: "ScapiaCoin", ext: "mp4", playOnce: true, rate: 0.75)
    .frame(width: 237, height: 283)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .scaleEffect(appeared ? 1 : 0.85)
    .opacity(appeared ? 1 : 0)
    .position(x: w/2, y: artCenterY)
```
- `ScapiaCoin.mp4`, **plays once**, **holds last frame** (the bolt), playback **rate 0.75**, **muted**, gravity `.resizeAspectFill`.
- Display frame `237 × 283`, corner radius `16` (continuous).
- Fades + scales in with `appeared` (scale 0.85→1, opacity 0→1) — same spring as t=0.20.

**Flutter:** `video_player` package, `..setVolume(0)`, `..setPlaybackSpeed(0.75)`, play once, on completion `pause()` at last frame. Wrap in `ClipRRect(borderRadius: 16)`, `SizedBox(237×283)`, animated scale/opacity.

---

## 10. Absolute layout — rewards screen (`rewardsScreen`)

Background: `LinearGradient([rewardsBgTop #EF6004, tripCardGradientBottom #FDD910], top→bottom)`, `.ignoresSafeArea()`.

Inside `GeometryReader { geo }`, `w = geo.size.width`. **Absolute positions mirror the Figma 390×840 frame.** (`.position` in SwiftUI sets the **center**.)

| Element | Center X | Center Y | Size / notes |
|---|---|---|---|
| Coin video | `w/2` | `artCenterY = 59 + 283/2 = 200.5` | 237×283, radius 16 |
| Earned number | `w/2` | `numberY = 352 + 40 = 392` (`+ numberLift` when lifting) | see §5; masked (§6d) |
| "Travel rewards earned" | `w/2` | `labelY = 444 + 36 = 480` | semibold 28, color `rewardsLabel`, width 241, centered |
| "Instantly added to your balance" | `w/2` | `numberY = 392` | bold 32, color `rewardsLabel`, width 301, lineSpacing `40 - 32*1.2 = 1.6`, wipe mask (§10a) |
| Particle layer | center `(w/2, numberY)`, target `pill` | — | `allowsHitTesting(false)` |
| Balance pill | `pill = (w/2, 20 + 30 = 50)` | — | see §10b |

### 10a. "Instantly added" wipe mask
The text is masked by a sliding feathered gradient (offset is animatable, gradient stops are not):
- `GeometryReader { g }`, `tw = g.size.width`, `feather = 150`.
- `HStack(spacing: 0)`: `Rectangle().fill(.white).frame(width: tw)` followed by a `LinearGradient` (leading→trailing) of width `feather` with stops:
  - white @ 0.0 (loc 0), white @ 0.85 (loc 0.22), white @ 0.5 (loc 0.5), white @ 0.18 (loc 0.78), clear (loc 1).
- Whole mask frame `width: tw + feather, alignment: .leading`, offset `x: -(tw+feather) + (tw+feather)*headingReveal`.
- `headingReveal` animates 0→1 over easeInOut 1.2s at t=3.42, sliding the soft edge left→right.

### 10b. Balance pill (`balancePill(value)`)
Layered structure (innermost → outermost):
1. **Content** `HStack(spacing: 8)`: `PillCoin` image `32×32` (`.interpolation(.high)`), `Text(grouped(value))` extraBold 24, color `balanceInk #141C20`, `tracking 0.96`, then `Spacer`.
   - Padding: `.leading 12`, `.trailing 16`. Frame `width 152, height 52`.
   - Background `Capsule().fill(.white)`.
2. `.padding(4)` then a **warm ring** `Capsule().fill(LinearGradient([rewardsGradientTop#E96307 @0.55, tripCardGradientBottom#FDD910 @0.55], top→bottom))` → a 4px gradient border.
3. **Shine overlay** (`opacity = shineActive ? 1 : 0`), a `ZStack`:
   - Constant rim: `Capsule().strokeBorder(white @0.22, lineWidth 1)`.
   - `gleam = AngularGradient` with stops (white opacities by location): 0@0.0, 0@0.32, 0.35@0.42, 1@0.49, 1@0.51, 0.35@0.58, 0@0.68, 0@1.0; center `.center`, `angle: .degrees(shineAngle)`.
   - Soft bloom: `Capsule().strokeBorder(gleam, lineWidth 8).blur(radius 6)`.
   - Crisp gleam: `Capsule().strokeBorder(gleam, lineWidth 2.5)`.
4. `.shadow(color: white @0.64, radius 22)`.
- Pill transform: `.scaleEffect(pillShown ? pillPulse : 0)`, `.opacity(pillShown ? 1 : 0)` — springs from scale 0; `pillPulse` does 1→1.07→1 during shine.

`grouped(n)` = `NumberFormatter` decimal, grouping separator `,`.

---

## 11. Absolute layout — trip screen (`tripScreen`)

Background: `LinearGradient([bgTop #FFF8EE, bgBottom #F7F9F4], top→bottom)`, `.ignoresSafeArea()`. `ZStack(alignment: .top)`.

Main `VStack(spacing: 0)`:
1. `heading` — `.padding(.top, 14)`, `opacity(headingShown ? 1 : 0)`.
2. Spacer height `26`.
3. `tripCard` with `EntranceEffect(trigger: entranceTrigger, w: cardW, h: cardH)`.
4. Spacer height `24`.
5. Subtitle `Text("Special perk for your London trip")` — regular 14, `black @0.56`, `opacity(bodyShown ? 1 : 0)`.
6. Spacer height `12`.
7. `offerCard` — `opacity(bodyShown ? 1 : 0)`.
8. Spacer (flex).

**Close button** (overlay, top-right): SF Symbol `xmark`, system size 13 semibold, `black @0.7`, frame `32×32`, `Circle().fill(closeBG #E9EBE7)`, aligned trailing, `.padding(.trailing, 16)`, `.padding(.top, 14)`.

### 11a. `heading`
`Text("Your flight is successfully booked")` — bold 24, black, centered, `lineSpacing(32 - 24*1.2 = 3.2)`, `frame(width: 272)`.

### 11b. `tripCard` (326 × 401)
`ZStack(alignment: .top)`:
- `RoundedRectangle(cornerRadius: 32, continuous).fill(.white)`.
- Same rect filled with `LinearGradient([cardMint#BDE3DF @0.5, tripCardGradientBottom#FDD910 @0.5], top→bottom)`.
- `VStack(spacing: 8)`: `tripDetails` (310×321), `coinsPill` (302×52). `.padding(.top, 8)`.
- Outer: `.frame(326×401)`, `.shadow(black @0.12, radius 87, x 0, y 0)`.

### 11c. `tripDetails` (310 × 321), bg `detailBG #F8FAF5`, clip `RoundedRectangle(24, continuous)`
`VStack(spacing: 0)`:
- **Plane image area**, `ZStack`: `imageBG #FEF8E9` + `Image("FlightPlane").scaledToFit().frame(width: 204)`. Frame `height 113`, `.clipped()`.
- **Info block** `VStack(alignment: .leading, spacing: 8)`, `.padding(.horizontal, 16)`, `.padding(.top, 16)`:
  - Row `HStack(alignment: .center)`: `deltaLogo` (= `Image("EmiratesLogo").scaledToFit().frame(width: 90)`), Spacer, then `HStack(spacing: 6)`: `Text("PNR:")` regular 12 `black@0.6`; `Text("ASD62D")` regular 12 black, `.padding(.horizontal 4, .vertical 2)`, overlay `RoundedRectangle(4, continuous).strokeBorder(black@0.33, dash [3], lineWidth 1)`.
  - `Text("London to Delhi")` semibold 20 black.
  - `HStack(spacing: 4)`: `Image("CalendarIcon") 16×16` + `Text("June 27, Sunday")` regular 14 `black@0.6`.
  - `Text("Name 1, Name 2")` regular 12 `black@0.6`.
- `Spacer`.
- **"View booking details" pill** `HStack(spacing: 4)`: `Text("View booking details")` medium 14 white + `Image("ArrowRight") 20×20`. Padding `.leading 20, .trailing 8, .vertical 12`. Background `Capsule().fill(navy #031223)`. `.padding(.bottom, 16)`.

### 11d. `coinsPill` (302 × 52), bg `Capsule().fill(.white)`
`HStack(spacing: 8)`, `.padding(.leading 4, .trailing 20)`:
- `Image("PillCoin") 32×32` (`.interpolation(.high)`).
- `VStack(alignment: .leading, spacing: 0)`: `Text("Coins earned")` medium 14 `black@0.8`; `HStack(spacing: 0)`: `Image("BoltFill") 12×12` + `Text("Instantly added")` regular 12 `alertAmber #D48806`.
- `Spacer`.
- `VStack(alignment: .trailing, spacing: 0)`: `Text("5,790")` medium 14 black `tracking 0.56`; `Text("Worth Rs1152")` regular 10 `black@0.6`.

### 11e. `offerCard` (358 × 177)
`ZStack(alignment: .topLeading)`, clip `RoundedRectangle(12, continuous)`, `.shadow(black@0.04, radius 40, x0 y0)`:
- `RoundedRectangle(12, continuous).fill(.white)`.
- **Left image** `ZStack`: `offerBG #F9F7D1` + `Image("StayHut").scaledToFill().frame(width: 210).offset(x: -8)`. Frame `170 × 177`, `.clipped()`.
- `Text("Flat ₹2,500 off on your stay")` semibold 14 `green #389E0D`, lineSpacing `20 - 14*1.2 = 3.2`, width 147 leading, `.position(x: 186 + 147/2 = 259.5, y: 16 + 20 = 36)`.
- `Text("Explore from 1000+ stays")` regular 12 `black@0.8`, lineSpacing `16 - 12*1.2 = 1.6`, width 140 leading, `.position(x: 186 + 140/2 = 256, y: 60 + 16 = 76)`.
- **Countdown** `VStack(alignment: .leading, spacing: 2)`: `Text("REWARD EXPIRES IN")` regular 10 `tracking 1` `black@0.55`; `Text(countdownText)` medium 14 `textHighEmphasis #262B30`. Width 140 leading, `.position(x: 256, y: 127 + 19 = 146)`.

`countdownText` = `String(format: "%02d : %02d : %02d", h, m, s)` from `secondsLeft` (h = /3600, m = %3600/60, s = %60). Starts at **24 : 32 : 27**, ticks down once/sec.

---

## 12. Assets referenced by V2

| Asset | Type | Used as |
|---|---|---|
| `ScapiaCoin.mp4` | video | Coin→bolt morph |
| `PillCoin` | image | Balance pill + coins pill icon (32×32) |
| `FlightPlane` | image | Trip card plane (width 204) |
| `EmiratesLogo` | image | Airline logo "deltaLogo" (width 90) |
| `CalendarIcon` | image | Date row (16×16) |
| `ArrowRight` | image | Booking pill arrow (20×20) |
| `BoltFill` | image | "Instantly added" bolt (12×12) |
| `StayHut` | image | Offer card image (width 210) |
| `LexendDeca-VF.ttf` | font | All text (6 weights) |

Copy all of these into the Flutter project (`assets/`) at full resolution. Vector assets (`ArrowRight`, `CalendarIcon`, `BoltFill` are SVG in the asset catalog) → use `flutter_svg` or pre-rasterized PNGs.

---

## 13. Flutter port plan

### 13.1 Project setup
1. New Flutter package/screen `trip_announcement_v2`.
2. `pubspec.yaml`:
   - Fonts: register Lexend Deca with all 6 weights (use the static instances extracted from the VF, or the VF with explicit `fontWeight`/`fontVariations` per `TextStyle`). Names → families `LexendDeca` with weights w400–w900 as in §3.
   - Assets: all of §12. Add `video_player`, `flutter_svg` (for SVGs), optionally a haptics plugin.
3. Port `DesignColors`/`DesignFont` → a `design_tokens.dart` with `const Color(0xFFRRGGBB)` and `TextStyle` helpers. **Copy every hex from §2 exactly.**

### 13.2 Architecture mapping
| Swift | Flutter |
|---|---|
| `struct ...View: View` + `@State` | `StatefulWidget` + fields; use `AnimationController`s |
| `.task { runSequence() }` | `initState` → `_runSequence()` async (`Future`), guarded by `mounted` |
| `Task.sleep(nanoseconds:)` | `await Future.delayed(Duration(milliseconds:))` |
| `withAnimation(curve)` { state } | drive an `AnimationController` with matching `Duration` + `Curve`, or `TweenAnimationBuilder` / `AnimatedFoo` widgets |
| `.position(x,y)` (center) | `Positioned` in a `Stack` with `left/top = x - size/2` (or `Align` + `Transform.translate`); replicate the 390×840 absolute layout inside a fixed-aspect `Stack` sized to the screen width |
| `GeometryReader { geo.size.width }` | `LayoutBuilder` / `MediaQuery.size.width` |
| `LinearGradient` | `LinearGradient` (Alignment.topCenter→bottomCenter) |
| `RoundedRectangle(cornerRadius, .continuous)` | `ClipRRect`/`Container` with `BorderRadius.circular`; for *continuous* corners use `ContinuousRectangleBorder` (Flutter has it) to match Apple's superellipse |
| `.mask(...)` | `ShaderMask` or `ClipRect`/`ClipPath` (rect-height mask → `ClipRect` with animated `heightFactor`/`Align`) |
| `Canvas` + `TimelineView(.animation)` | `CustomPainter` + `AnimationController(vsync, unbounded)` repainting every frame (or `Ticker`) |
| `keyframeAnimator` (entrance) | a single `AnimationController` (1.0s) with `Interval`/`TweenSequence` per property (§7 table) |
| Metal `cardWarp` | Flutter `FragmentProgram` GLSL shader (see §13.5) |
| `UIImpactFeedbackGenerator` / CoreHaptics | `HapticFeedback` + plugin (best-effort) |

### 13.3 Curve mapping (Swift → Flutter)
| Swift | Flutter |
|---|---|
| `.easeInOut(duration:)` | `Curves.easeInOut`, matching `Duration` |
| `.easeOut(duration:)` | `Curves.easeOut` |
| `.linear(duration:)` | `Curves.linear` |
| `.linear(...).repeatForever(autoreverses: false)` | `controller.repeat()` over linear, period = 1.9s |
| `.spring(response:R, dampingFraction:D)` | `SpringSimulation` via `controller.animateWith(SpringSimulation(SpringDescription.withDampingRatio(mass: 1, stiffness: ..., ratio: D), ...))`. Convert response→stiffness: `stiffness = (2π / R)^2`, `damping = 4π·D / R` (mass 1). **Use these formulas so spring feel matches.** Springs used: (0.5, 0.82) appear, (1.0, 0.82) digit roll, (0.42, 0.56) pill, plus implicit. |

> SwiftUI spring: `stiffness = (2π/response)^2`, `dampingRatio = dampingFraction`. Flutter `SpringDescription.withDampingRatio(mass: 1.0, stiffness: stiffness, ratio: dampingFraction)`. This is the faithful conversion.

### 13.4 Build order (recommended)
1. **Static layouts first**, value-for-value, no animation:
   - `rewardsScreen` static (coin frame, number, label, pill) per §10.
   - `tripScreen` static (heading, trip card §11b–d, offer card §11e) per §11.
   - Verify pixel positions against the Figma 390×840 reference.
2. **Phase 1 (earned):** coin video (§9), rolling ticker (§5), `appeared` spring, `tickerBurst` haptics.
3. **Phase 2 (added):** the hard part —
   - Glyph rasterization + sampling (`dart:ui` `Picture`→`Image`→`toByteData`, read pixels, gray>110 with the same `step` formula) to build `dissolveDots` per §6a (same ranges/probabilities/×3/drop-20%).
   - `ParticleDissolvePainter` (`CustomPainter`) implementing §6c exactly (born/travel/settle math, ease `1-pow(1-prog,3)`, arc `sin(prog·π)`, orbit, twinkle, opacity, ellipse fill).
   - Number sweep mask §6d via animated `ClipRect`.
   - Balance pill spring-in + count-up (`stepCount` 46×32ms) + warm-ring gradient + angular-gradient shine (`SweepGradient` rotated by `shineAngle`, two stroke layers + blur) + `pillPulse`.
   - "Instantly added" sliding feather mask §10a (`ShaderMask` with a horizontally-translated `LinearGradient`).
   - Continuous haptic start/stop.
4. **Phase 3 (trip):** crossfade `phase`, fire entrance keyframes §7, warp shader §13.5, heading/body fades.
5. **Offer countdown:** `Timer.periodic(1s)` decrementing `secondsLeft` from 88,347.

### 13.5 The warp shader in Flutter
Write a GLSL fragment shader (Flutter's `FragmentProgram`, declared under `flutter: shaders:` in pubspec) that takes `uSize` (vec2), `uAmount` (float), and the card as a `uSampler2D`. Sample at `(position.x + xShift, position.y)` where `xShift = uAmount * cos((position.y/uSize.y) * 1.5707963) * 28.0`. Apply via an `AnimatedSampler` (from the `flutter_shaders` package) wrapping the card during the entrance only (when `warp > 0.001`). `maxSampleOffset` is implicit in GLSL.

> If a fragment shader is too heavy to start with, an acceptable first pass is a `Transform`/`Matrix4` perspective-tilt approximation — but the **faithful** port uses the shader with `maxShift = 28.0` and `cos(ny·π/2)`.

### 13.6 What must NOT change (acceptance criteria)
- Every **color hex** (§2), **font size + weight** (§3, used inline), **dimension** (frames, paddings, radii, positions in §10–§11), **duration/delay/curve** (§4, §7), **spring response/damping** (§13.3), **particle parameter range/probability/count** (§6), **counts** (32,800 / 5,790 / countdown 24:32:27 / 46 steps / 32ms / 11 haptic ticks etc.).
- The earned number is **32,800**; balance target **5,790**; "Worth Rs1152"; PNR **ASD62D**; route **London to Delhi**; date **June 27, Sunday**; "Flat ₹2,500 off"; "Explore from 1000+ stays".
- Total sequence timing must land on the same `t` values in §4.

---

## 14. Open questions / device caveats for the port
1. **Haptic intensity**: Flutter cannot set impact intensity (0.85) or a custom CoreHaptics continuous rumble (intensity 0.32 / sharpness 0.18) without a platform channel. Decide: platform-channel to CoreHaptics (faithful) vs. `HapticFeedback.mediumImpact()` approximation.
2. **Continuous-corner rounding**: SwiftUI `.continuous` (superellipse) vs Flutter `ContinuousRectangleBorder` — use the latter to match; `BorderRadius.circular` is slightly different.
3. **Glyph sampling parity**: ensure the Flutter rasterization uses Lexend Deca **Black** at **64pt**, scale 2, gray threshold **>110**, and the same `step = max(2, sqrt(w*h*0.35/maxCount))`, maxCount **180** (comma) / **1020** (digit), to reproduce the cloud shape.
4. **Variable-font weights**: confirm the six Lexend Deca instances render identically; if using the VF, set `fontVariations: [FontVariation('wght', N)]`.

---

*Generated from `TripAnnouncementViewV2.swift` and dependencies at commit `8e24fbd`. Every literal value above is copied from source.*

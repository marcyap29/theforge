# The Forge — Design Language

*Mark, palette, and usage rules. v1, 2026-09-08.*

Derived from the TALA brand identity (`Tala_BrandIdentity_v2`) and the
Sabihin design system (`docs/Sabihin-Design-Language.md`). The Forge sits
in the same house: instrument precision, warm metal, dark ground, one
accent doing all the work. Where it diverges from TALA, the divergence is
deliberate and called out.

---

## 1. The mark

**Name: the Hearth Dial.**

Same construction logic as TALA's Layag Mark: a working instrument fused
with the thing it measures. TALA's instrument is a navigation bezel and
the thing it points at is a star. The Forge's instrument is a gauge and
the thing it watches is heat.

### Elements

**Outer tick bezel.** Sixty ticks, every fifth one longer and brass.
Cockpit instrument language, the same reference TALA uses. It exists to
say the dial is calibrated, not decorative.

**Progress arc.** Brass, drawn from the lower left, clockwise, stopping at
roughly 72% of the live dial. The remaining sweep continues in Voyager
Steel at low opacity. This is the product's actual job rendered as
geometry: a build partway through, with the finished portion in warm metal
and the unbuilt portion in cold steel.

**Position marker.** A single ivory tick crossing the arc where brass
meets steel. The current state of the build. This is the one element that
would move if the mark were ever animated.

**Opening at the bottom.** The bezel is a 320° arc, not a closed ring, and
the gap sits at six o'clock. TALA's gap is at the top, where the star's
north arm pushes through, and it means the instrument only takes you so
far. The Forge inverts it. The opening is at the bottom because the dial
is open at the base, the way a hearth is.

**Ember core.** A four-arm concave star, horizontally dominant (roughly
1.66:1), with a white-hot centre. TALA's star is vertically dominant and
navy, a cold celestial body. The Forge's is wide, low, and hot: a spark
struck off metal, not a star in the sky. That inversion is the single
clearest way to tell the two marks apart at a glance.

**Heat bloom.** A soft radial wash behind the ember on the dark tile. It
carries no meaning on its own and disappears cleanly at small sizes.

### Tile

Rounded superellipse (squircle, n=5), never a plain rounded rectangle and
never a circle. Same rule Sabihin follows, so the two icons sit correctly
next to each other in a dock.

---

## 2. Palette

Dark-first. TALA's navy and brass carry the family resemblance. The ember
gradient is Forge-specific and is the only place The Forge departs from
the TALA swatches.

### Shared with TALA

| Token | Hex | Use |
|---|---|---|
| `gabi-navy` | `#0E1B2E` | Primary ground |
| `navy-lift` | `#152A40` | Tile gradient, top |
| `navy-deep` | `#08131F` | Tile gradient, bottom |
| `instrument-brass` | `#A9793F` | Progress arc, major ticks, bezels |
| `brass-shade` | `#8A6234` | Brass gradient, lower stop |
| `voyager-steel` | `#6C7C88` | Unbuilt arc, minor ticks, fine lines |
| `capiz-ivory` | `#EFE7D8` | Position marker, white-hot core, text on navy |
| `balatik-rust` | `#7A3826` | Heat bloom only. Used sparingly, as the ember |

### Forge-specific accent

| Token | Hex | Use |
|---|---|---|
| `ember-hi` | `#FFC46B` | Ember gradient, top |
| `ember` | `#FF7A2F` | **Primary accent.** Flat ember fill, live/active state |
| `ember-lo` | `#B4451C` | Ember gradient, bottom |

### CSS custom properties

```css
:root {
  --frg-navy:       #0E1B2E;
  --frg-navy-lift:  #152A40;
  --frg-navy-deep:  #08131F;
  --frg-brass:      #A9793F;
  --frg-brass-lo:   #8A6234;
  --frg-steel:      #6C7C88;
  --frg-ivory:      #EFE7D8;
  --frg-rust:       #7A3826;
  --frg-ember-hi:   #FFC46B;
  --frg-ember:      #FF7A2F;
  --frg-ember-lo:   #B4451C;
}
```

### Rules of thumb

- One accent. Ember is reserved for live state, the active build, and the
  single most important action in a view. Everything else is brass, steel,
  or ivory.
- Brass means done. Steel means not yet. Ember means happening now. Keep
  that mapping consistent in the app UI, not just the icon, and the icon
  becomes a legend for the product.
- Elevation by surface swap, not drop shadow. Borders are hairlines.
- Text on ember is `navy-deep`, never white.

---

## 3. Typography

Inherits TALA's stack, since both are Orbital AI properties.

| Family | Role | Source |
|---|---|---|
| **Unbounded** | Wordmark, headlines, dial text | Google Fonts |
| **Fraunces** | Body, storytelling, long-form copy | Google Fonts |
| **IBM Plex Mono** | Specs, counters, commit hashes, timestamps. Tabular figures | Google Fonts / IBM |

The Forge is a tool that shows numbers constantly (token spend, commit
counts, percentages). Plex Mono with tabular figures is not optional in
those places, or the numbers jitter as they update.

---

## 4. Size variants

Three drawings, not one drawing scaled. The mark is dense at 1024 and
would turn to mush if reduced mechanically.

| Variant | Used at | What changes |
|---|---|---|
| `forge_icon_master.svg` | 64px and up | Everything: ticks, both arcs, marker, bloom |
| `forge_icon_32.svg` | 24px to 48px | Ticks, marker and bloom dropped. Arc doubled in weight. Ember flat, no gradient |
| `forge_icon_16.svg` | 20px and below | Ember only, oversized, on the tile. Arc dropped entirely |

Marks (transparent background) come in two grounds:

| File | Ground |
|---|---|
| `forge_mark_dark.svg` | Navy or any dark surface. Ivory centre |
| `forge_mark_light.svg` | Ivory, paper, white. Navy centre, no bloom, steel arc darkened |

Never place the dark mark on a light background or the reverse. The centre
dot vanishes and the arc loses contrast.

---

## 5. Usage rules

- Clear space on all sides is at least the radius of the ember star.
- Never recolour the ember. It is the one thing that identifies the brand.
- Never close the bezel into a full ring. The gap at six o'clock is the
  mark.
- Never rotate the mark. The progress arc reads as a value, and rotating
  it changes what that value appears to be.
- Do not add a drop shadow to the tile. macOS adds its own.
- The mark can be used with the ember alone (the 16px variant) as a
  standalone glyph for bullets, favicons and menu-bar items. It cannot be
  used as the primary logo on its own, since a four-point sparkle is not
  distinctive without the dial.

---

## 6. Files

```
svg/
  forge_icon_master.svg     tile, full detail, 1024 viewBox
  forge_icon_32.svg         tile, simplified
  forge_icon_16.svg         tile, ember only
  forge_mark_dark.svg       transparent, for dark grounds
  forge_mark_light.svg      transparent, for light grounds
  forge_mark_32.svg         transparent, simplified
appicon/
  app_icon_16/32/64/128/256/512/1024.png
png/
  forge_icon_2048.png, forge_icon_512.png
  forge_mark_dark_512.png, forge_mark_light_512.png, forge_mark_64.png
```

The `appicon/` filenames match what Flutter's macOS runner expects at
`macos/Runner/Assets.xcassets/AppIcon.appiconset/`. Dropping them in
replaces the default Flutter icon with no `Contents.json` change.

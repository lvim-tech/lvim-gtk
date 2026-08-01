# lvim-gtk

A desktop theme generated from [lvim-colorscheme](https://github.com/lvim-tech/lvim-colorscheme).
One palette, one desktop: the editor, the file manager, the window decorations and the shell all
end up wearing the same colours, because they are all derived from the same source.

Every style lvim-colorscheme ships becomes a complete theme — GTK2, GTK3, GTK4/libadwaita,
Metacity, XFWM4, GNOME Shell and Cinnamon — with no hand-maintained copies in between.

**This repository is source. You build the theme you want.** Nothing here is pre-generated: a
built theme is half a megabyte and there are forty-eight of them, so committing them would put
25 MB in git and regenerate three thousand files every time one colour changed. Building needs
`sass` and `python3`, and takes about a second per style.

If you would rather not read the rest of this first:

```sh
scripts/setup
```

walks through the whole thing — checking what is installed, fetching the colours, letting you pick
a style, building it and installing it.

## What a built theme contains

| Directory | What reads it |
| --- | --- |
| `gtk-3.0/` | every GTK3 application, plus `lvim-assets/` for the check, radio and window-control glyphs |
| `gtk-4.0/` | GTK4 and libadwaita; installed to `~/.config/gtk-4.0/`, the only place libadwaita looks |
| `gtk-2.0/` | legacy GTK2 applications |
| `metacity-1/` | Metacity, Marco, GNOME Flashback, Compiz |
| `xfwm4/` | XFCE's window manager — `themerc` plus 62 generated images |
| `gnome-shell/` | GNOME Shell, through the User Themes extension |
| `cinnamon/` | the Cinnamon desktop, plus the 14 images its stylesheet names |

## Building

```sh
scripts/palettes                 # pull the colours out of lvim-colorscheme
scripts/build everforest_dark    # build one style into build/Lvim-EverforestDark
scripts/install Lvim-EverforestDark
```

`scripts/palettes` does not need lvim-colorscheme checked out. A local copy wins when there is one,
because regenerating after editing a palette is the point of running it; otherwise the sources are
downloaded into `~/.cache/lvim-gtk/`.

```sh
scripts/palettes --repo                # always the published sources
scripts/palettes --repo --ref v2.1.0   # a tag or a branch
scripts/palettes --colorscheme ~/src/lvim-colorscheme
```

To build every style:

```sh
for p in palettes/*.scss; do scripts/build "$(basename "$p" .scss)"; done
```

`scripts/install` writes the theme to `~/.local/share/themes/`, copies the GTK4 half to
`~/.config/gtk-4.0/`, and sets `gtk-theme-name` in **both** GSettings and `settings.ini` — the two
disagree otherwise, and which one wins depends on how the application was launched.

GNOME Shell and Cinnamon themes are selected in their own settings, not by `gtk-theme-name`.

## How it is put together

```
palettes/<style>.scss     raw colours, generated from lvim-colorscheme
        │
src/sass/_semantic.scss   what each colour is FOR — measured, not assumed
        │
src/sass/_config.scss     everything that is not a colour: radii, sizes, timing
        │
        ├── gtk3/, gtk4/, shell/, cinnamon/     stylesheets, via Sass
        └── templates/, scripts/*-assets        the toolkits that are not CSS
```

The semantic layer is the reason a new palette costs nothing. A widget rule never names a colour —
it names a role, `$accent` or `$surface` or `$on-surface`, and the role is resolved once. Swapping
the palette swaps every surface, border and state in one step.

That layer also **measures**. Editor palettes are deliberately low-contrast; taken literally they
give a desktop where secondary text sits at 2.3:1 against its own background. So foregrounds are
walked away from their background until they clear a WCAG threshold, keeping their hue, and the
accent is walked away from the side its own text will come from — a fill that cannot carry a label
is not a usable accent no matter how good it looks empty.

The toolkits that predate stylesheets — GTK2's rc files, Metacity's XML, XFWM4's `themerc` — are
rendered from templates by `scripts/legacy`, which reads the colours back out of the compiled GTK3
css. They consume the semantic layer's answers rather than re-deriving them, because two
implementations of the same derivation disagree the day either one changes.

Two toolkits need pictures rather than rules: XFWM4 draws its titlebar buttons from image files,
and Cinnamon points `background-image` at a checkbox it cannot draw itself. Those are generated per
palette by `scripts/xfwm-assets` and `scripts/cinnamon-assets`.

## Configuration

Everything that is not a colour lives in `src/sass/_config.scss`. Each value is a `!default`, so a
build can override any of them, and each names a ROLE rather than a widget — roundness comes back
one family at a time rather than by hunting through the widget files.

```scss
// ── Corners ──────────────────────────────────────────────────────────────────
// The theme ships square. Set any of these to bring a family of corners back.
$radius:                 0;          // buttons, entries, the common case
$radius-small:           0;          // checkboxes, small controls, badges
$radius-large:           0;          // cards, dialogs, popovers, menus
$radius-window:          0;          // the window's own corners
$radius-track:           0;          // switch, scrollbar slider, scale, progress
$radius-active:          0;          // anything FILLED with the accent
$radius-radio:           9999px;     // stays round: it is what tells a radio from a checkbox
$radius-avatar:          9999px;     // stays round: it is a portrait

// ── Spacing ──────────────────────────────────────────────────────────────────
$space-1:                2px;
$space-2:                4px;
$space-3:                6px;
$space-4:                8px;
$space-5:                12px;
$space-6:                16px;
$space-7:                24px;

// ── Sizes ────────────────────────────────────────────────────────────────────
$header-height:          46px;
$control-height:         34px;       // buttons, entries, comboboxes
$control-height-sm:      26px;
$icon-size:              16px;
$check-size:             16px;       // the box of a checkbox / radio, glyph included
$check-spacing:          4px;        // gap between that box and its label
$scrollbar-width:        8px;
$scrollbar-width-hover:  12px;

// ── Window manager decorations ───────────────────────────────────────────────
// Read by scripts/legacy and scripts/xfwm-assets as well as by the stylesheets, so the images and
// the themerc cannot disagree about how tall a title bar is.
$wm-title-height:        34px;
$wm-button-size:         26px;
$wm-glyph:               10px;
$wm-border:              1px;

// ── Lines ────────────────────────────────────────────────────────────────────
$border-width:           1px;
$focus-width:            2px;
$focus-offset:           -3px;

// ── Motion ───────────────────────────────────────────────────────────────────
$duration-fast:          100ms;
$duration:               150ms;
$duration-slow:          250ms;
$easing:                 cubic-bezier(0.25, 0.46, 0.45, 0.94);

// ── Density ──────────────────────────────────────────────────────────────────
$density:                'default';  // or 'compact'

// ── Selection ────────────────────────────────────────────────────────────────
// A list row fills solid; a grid cell takes a wash, because a solid fill paints over the very
// thumbnail being selected.
$selection-cell-alpha:   0.25;       // 0 leaves only the name marked
$selection-label-radius: 2px;
$hover-label-alpha:      0.12;       // weaker than selection: pointing at is not choosing

// ── Switches ─────────────────────────────────────────────────────────────────
// Some applications neutralise the accent inside their own window — Nautilus greys out the
// selection in its file views so thumbnails are not tinted. On, the theme re-asserts its accent
// there; off, the application's decision stands.
$app-accent-override:    true;
$shadows:                true;       // depth via shadow; off gives a flat look
$gradients:              false;      // subtle gradients on raised surfaces
$rimless:                false;      // drop the window border entirely
$flat-headerbar:         false;      // headerbar shares the window background
```

The colour side has one knob of its own, in `src/sass/_semantic.scss`:

```scss
// Which palette colour is the desktop's accent. Sourced from the same key lvim-colorscheme uses
// for TabLineSel and Title — its own "this is the chosen one" — so the desktop's selection agrees
// with the editor's, and each palette keeps its own identity.
$accent-source: p.$green-dark;
```

## Requirements

`sass` and `python3` to build. `nvim` to regenerate the palettes, because a third of
lvim-colorscheme's styles are functions rather than tables and only Neovim can evaluate them.

## Licence

BSD-3-Clause. Written from scratch — nothing is forked or copied from another theme.

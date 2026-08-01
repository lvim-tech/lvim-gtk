# lvim-gtk — the parts more than one script needs. Sourced, never executed.
#
# It exists for one function in particular. ACTIVATING a theme is not setting `gtk-theme-name`:
# libadwaita ignores that setting entirely and reads only ~/.config/gtk-4.0/gtk.css, so every switch
# has to copy the GTK4 half as well. Three scripts need that — install, select and setup — and three
# copies of it would drift the first time one of them learned something the others did not.
#
# It is also why no general theme switcher can change this theme correctly: they all set the name
# and stop, which leaves GTK4 applications on whatever was there before.

THEMES="${XDG_DATA_HOME:-$HOME/.local/share}/themes"
CFG3="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0"
CFG4="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0"

bold=$'\033[1m'; dim=$'\033[2m'; green=$'\033[32m'; red=$'\033[31m'; yellow=$'\033[33m'; off=$'\033[0m'
step() { printf '\n%s▸ %s%s\n' "$bold" "$1" "$off"; }
ok()   { printf '  %s✓%s %s\n' "$green" "$off" "$1"; }
bad()  { printf '  %s✗%s %s\n' "$red" "$off" "$1"; }
note() { printf '  %s%s%s\n' "$dim" "$1" "$off"; }
warn() { printf '  %s!%s %s\n' "$yellow" "$off" "$1"; }

# ask "question" "default" — returns the default when there is no terminal, so every script here
# can be run from a pipe or a cron job without hanging on a prompt nobody will see.
ask() {
    local reply
    if [ ! -t 0 ]; then printf '%s\n' "$2"; return; fi
    read -r -p "  $1 [$2]: " reply </dev/tty
    printf '%s\n' "${reply:-$2}"
}

# pick <prompt> [marked] — choose a line from stdin with the arrow keys. Prints the choice.
#
# Written out rather than delegated to fzf because this file is installed outside the repository and
# has to keep working on a machine that has none of that. fzf IS used when it happens to be there —
# forty-eight themes are worth typing a few letters to narrow — but it is a bonus, never a
# requirement.
#
# Everything is drawn to /dev/tty, never to stdout, because stdout is the answer. Redrawing moves
# the cursor back up rather than clearing the screen, so the scrollback above stays intact.
pick() {
    local prompt="$1" marked="${2:-}" items=() n i
    while IFS= read -r line; do items+=("$line"); done
    n=${#items[@]}
    [ "$n" -gt 0 ] || return 1

    # No terminal to draw on: fall back to the first item, the same way ask() falls back to its
    # default. Scripts here must never hang waiting for a person who is not there.
    if [ ! -t 0 ] && [ ! -r /dev/tty ]; then printf '%s\n' "${items[0]}"; return; fi

    if command -v fzf >/dev/null; then
        local out
        out=$(printf '%s\n' "${items[@]}" | fzf --height=60% --reverse --no-multi \
              --prompt="$prompt " --query="" --select-1 </dev/tty) || return 1
        printf '%s\n' "$out"
        return
    fi

    local cur=0 top=0 rows page
    for i in "${!items[@]}"; do [ "${items[$i]}" = "$marked" ] && cur=$i; done
    rows=$(tput lines 2>/dev/null || echo 24)
    page=$(( rows - 6 )); [ "$page" -lt 5 ] && page=5; [ "$page" -gt "$n" ] && page=$n

    local drawn=0
    _draw() {
        [ "$drawn" -gt 0 ] && printf '\033[%dA' "$drawn" > /dev/tty
        printf '  %s%s%s  %s↑↓ move · enter choose · q cancel%s\033[K\n' \
               "$bold" "$prompt" "$off" "$dim" "$off" > /dev/tty
        [ "$cur" -lt "$top" ] && top=$cur
        [ "$cur" -ge $(( top + page )) ] && top=$(( cur - page + 1 ))
        local j
        for (( j = top; j < top + page && j < n; j++ )); do
            if [ "$j" -eq "$cur" ]; then
                printf '  %s▸ %s%s' "$green" "${items[$j]}" "$off" > /dev/tty
            else
                printf '    %s' "${items[$j]}" > /dev/tty
            fi
            [ "${items[$j]}" = "$marked" ] && printf '  %s(active)%s' "$dim" "$off" > /dev/tty
            printf '\033[K\n' > /dev/tty
        done
        printf '  %s%d/%d%s\033[K\n' "$dim" $(( cur + 1 )) "$n" "$off" > /dev/tty
        drawn=$(( page + 2 ))
    }

    # The cursor is hidden while drawing, so it must come back however this ends — including a
    # Ctrl-C, which otherwise leaves the terminal with no cursor and no obvious way to get it back.
    trap 'tput cnorm 2>/dev/null > /dev/tty || true' EXIT INT TERM
    tput civis 2>/dev/null > /dev/tty || true
    _draw
    local key rest
    while IFS= read -rsn1 key < /dev/tty; do
        case "$key" in
            $'\e')
                read -rsn2 -t 0.01 rest < /dev/tty || rest=""
                case "$rest" in
                    '[A') [ "$cur" -gt 0 ] && cur=$(( cur - 1 )) ;;
                    '[B') [ "$cur" -lt $(( n - 1 )) ] && cur=$(( cur + 1 )) ;;
                    '[5') read -rsn1 -t 0.01 < /dev/tty; cur=$(( cur - page )); [ "$cur" -lt 0 ] && cur=0 ;;
                    '[6') read -rsn1 -t 0.01 < /dev/tty; cur=$(( cur + page )); [ "$cur" -ge "$n" ] && cur=$(( n - 1 )) ;;
                    '')   tput cnorm 2>/dev/null > /dev/tty || true; return 1 ;;
                esac
                ;;
            k) [ "$cur" -gt 0 ] && cur=$(( cur - 1 )) ;;
            j) [ "$cur" -lt $(( n - 1 )) ] && cur=$(( cur + 1 )) ;;
            g) cur=0 ;;
            G) cur=$(( n - 1 )) ;;
            q) tput cnorm 2>/dev/null > /dev/tty || true; return 1 ;;
            '') break ;;
        esac
        _draw
    done
    tput cnorm 2>/dev/null > /dev/tty || true
    printf '%s\n' "${items[$cur]}"
}

# theme_name <style-or-theme> — `everforest_soft` and `Lvim-EverforestSoft` both arrive here.
# Everything in this repository speaks in styles; only the built directory is capitalised.
theme_name() {
    case "$1" in
        Lvim-*) printf '%s\n' "$1" ;;
        *)      printf 'Lvim-%s\n' "$(echo "$1" | sed -E 's/(^|_)([a-z])/\U\2/g')" ;;
    esac
}

# installed_themes — the ones already in ~/.local/share/themes, newest first is not useful here so
# they come out sorted.
installed_themes() {
    find "$THEMES" -maxdepth 1 -mindepth 1 -type d -name 'Lvim-*' -printf '%f\n' 2>/dev/null | sort
}

# place <Theme-Name> — copy a built theme into ~/.local/share/themes and stop there.
#
# Separate from activate() because they are separate ideas, and conflating them is what made
# "install all of them" sound impossible. Placing forty-eight themes is perfectly sensible — it is
# what fills the list you choose from. ACTIVATING forty-eight is not: activation writes
# gtk-theme-name and copies one GTK4 stylesheet into place, so the forty-eighth would simply win.
place() {
    local name="$1" src="build/$1"
    [ -d "$src" ] || { bad "not built: $name"; return 1; }
    mkdir -p "$THEMES"
    rm -rf "${THEMES:?}/$name"
    cp -r "$src" "$THEMES/$name"
}

# activate <Theme-Name> — point every toolkit at an ALREADY INSTALLED theme. No building, no
# copying of the theme tree: this is the operation a switcher performs.
activate() {
    local name="$1" src="$THEMES/$1"
    [ -d "$src" ] || { bad "not installed: $name"; return 1; }

    mkdir -p "$CFG4"
    # Someone's own GTK4 css is preserved once, so a first run never destroys it.
    [ -f "$CFG4/gtk.css" ] && [ ! -f "$CFG4/gtk.css.before-lvim" ] \
        && ! grep -q "lvim-gtk" "$CFG4/gtk.css" 2>/dev/null \
        && cp "$CFG4/gtk.css" "$CFG4/gtk.css.before-lvim"
    cp "$src/gtk-4.0/gtk.css" "$CFG4/gtk.css"

    # The glyphs that stylesheet points at. url() resolves relative to the stylesheet, and the
    # stylesheet now lives here rather than in the theme directory, so its assets follow it.
    # Named lvim-assets rather than assets because this is a SHARED directory and another theme
    # generator has already left an assets/ of its own in it.
    rm -rf "$CFG4/lvim-assets"
    cp -r "$src/gtk-4.0/lvim-assets" "$CFG4/lvim-assets"

    # Two independent sources decide gtk-theme-name and must not be allowed to disagree. GSettings
    # is what a GNOME session and xdg-desktop-portal read; settings.ini is what GTK3 reads with no
    # settings daemon running — which is a plain wayland session, and what nwg-look writes. Set one
    # and the other still points at whatever came before, so which theme you get depends on how the
    # application happened to be launched.
    gsettings set org.gnome.desktop.interface gtk-theme "$name" 2>/dev/null || true

    mkdir -p "$CFG3"
    local ini="$CFG3/settings.ini"
    if [ ! -f "$ini" ]; then
        printf '[Settings]\ngtk-theme-name=%s\n' "$name" > "$ini"
    elif grep -q '^gtk-theme-name=' "$ini"; then
        sed -i "s|^gtk-theme-name=.*|gtk-theme-name=$name|" "$ini"
    else
        sed -i "0,/^\[Settings\]/s||[Settings]\ngtk-theme-name=$name|" "$ini"
    fi

    # A user gtk.css is loaded at PRIORITY_USER (800) and outranks the theme's 200, so anything left
    # there by a previous theme generator quietly overrides ours. Moved aside rather than deleted.
    if [ -e "$CFG3/gtk.css" ] && ! grep -q "lvim-gtk" "$CFG3/gtk.css" 2>/dev/null; then
        mkdir -p "$CFG3/before-lvim"
        mv "$CFG3/gtk.css" "$CFG3/before-lvim/gtk.css"
        note "moved $CFG3/gtk.css -> before-lvim/ (it was overriding the theme)"
    fi
}

# install_selector — put a working switcher outside the repository.
#
# THE REPOSITORY IS SOURCE AND MAY BE DELETED once the themes are installed; that is a perfectly
# reasonable thing to do with a source tree, and the themes in ~/.local/share/themes do not need it.
# The SWITCHER does, though, and no general theme switcher can replace it — they set gtk-theme-name
# and stop, leaving GTK4 applications on the previous theme.
#
# So a copy goes somewhere permanent. Not a rewrite: the same two files, in a second location, so
# there is still one implementation of activate() in the world.
install_selector() {
    local bindir="$HOME/.local/bin" libdir="${XDG_DATA_HOME:-$HOME/.local/share}/lvim-gtk"
    mkdir -p "$bindir" "$libdir"
    cp scripts/_common.sh "$libdir/common.sh"
    cp scripts/select "$bindir/lvim-gtk-select"
    chmod +x "$bindir/lvim-gtk-select"
}

# post_notes <Theme-Name> — what is NOT done by activating, and would otherwise be discovered the
# hard way.
post_notes() {
    local name="$1"
    printf '  GTK2/3/4 and the window decorations now point at %s.\n\n' "$name"
    note "Applications cache the theme at startup — restart them to see it."
    printf '\n'

    if command -v gnome-shell >/dev/null; then
        printf '  %sGNOME Shell%s — the shell theme is chosen SEPARATELY, through the User Themes\n' "$bold" "$off"
        printf '  extension, not by gtk-theme-name:\n'
        printf '    %sgsettings set org.gnome.shell.extensions.user-theme name "%s"%s\n\n' "$dim" "$name" "$off"
    fi
    if command -v cinnamon >/dev/null; then
        printf '  %sCinnamon%s — Settings → Themes → "Desktop", also separate from the GTK theme.\n\n' "$bold" "$off"
    fi
    if command -v xfwm4 >/dev/null; then
        printf '  %sXFWM4%s — Settings → Window Manager → %s\n\n' "$bold" "$off" "$name"
    fi
    if command -v marco >/dev/null || command -v metacity >/dev/null; then
        printf '  %sMetacity/Marco%s — the decoration theme ships in the same directory, chosen by name.\n\n' "$bold" "$off"
    fi

    # libadwaita reads the system colour scheme from the portal rather than from GSettings directly.
    # With no portal running it stays in light mode and makes light assumptions about shadows and
    # icon filters even though our colours still arrive. Worth saying: it looks like a theme bug.
    if ! busctl --user status org.freedesktop.portal.Desktop >/dev/null 2>&1; then
        warn "xdg-desktop-portal is not running on this session."
        note "libadwaita reads light/dark from it. Without it, GTK4 applications stay in LIGHT"
        note "mode — the colours are still ours, but shadows and icon filters assume a light"
        note "background."
    fi
}

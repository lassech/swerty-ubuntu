#!/bin/bash
# Installer swerty tastaturlayout (dk+swerty) på en ny Ubuntu-maskine
# Kør med: sudo bash install-swerty.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYMBOLS_FILE="$SCRIPT_DIR/dk_swerty"
XKB_SYMBOLS="/usr/share/X11/xkb/symbols/dk_swerty"
XKB_LST="/usr/share/X11/xkb/rules/evdev.lst"
XKB_XML="/usr/share/X11/xkb/rules/evdev.xml"

# Tjek at scriptet køres som root
if [ "$EUID" -ne 0 ]; then
    echo "Kør scriptet med sudo: sudo bash install-swerty.sh"
    exit 1
fi

# Tjek at layoutfilen findes ved siden af scriptet
if [ ! -f "$SYMBOLS_FILE" ]; then
    echo "Fejl: Kan ikke finde '$SYMBOLS_FILE'"
    echo "Sørg for at dk_swerty ligger i samme mappe som dette script."
    exit 1
fi

echo "==> Kopierer layoutfil..."
cp "$SYMBOLS_FILE" "$XKB_SYMBOLS"
echo "    $XKB_SYMBOLS oprettet."

echo "==> Opdaterer evdev.lst..."
if grep -q "swerty" "$XKB_LST"; then
    echo "    swerty allerede registreret i evdev.lst, springer over."
else
    # Indsæt linjen efter den eksisterende 'dk' variant-sektion
    sed -i '/^  nodeadkeys.*dk:/a\  swerty          dk: swerty' "$XKB_LST"
    echo "    swerty tilføjet til evdev.lst."
fi

echo "==> Opdaterer evdev.xml..."
if grep -q "swerty" "$XKB_XML"; then
    echo "    swerty allerede registreret i evdev.xml, springer over."
else
    # Indsæt variant-blokken inden </variantList> under dk-layoutet
    python3 - "$XKB_XML" <<'PYEOF'
import sys
import re

path = sys.argv[1]
with open(path, "r") as f:
    content = f.read()

new_variant = """\t<variant>
          <configItem>
            <name>swerty</name>
            <description>Swerty</description>
          </configItem>
        </variant>"""

# Find dk-layoutets variantList og tilføj swerty som sidste variant
# Matcher blokken der indeholder <name>dk</name> og dennes </variantList>
pattern = r'(<name>dk</name>.*?<variantList>)(.*?)(</variantList>)'
def replacer(m):
    return m.group(1) + m.group(2) + "\n        " + new_variant + "\n      " + m.group(3)

new_content, count = re.subn(pattern, replacer, content, count=1, flags=re.DOTALL)
if count == 0:
    print("    Advarsel: Kunne ikke finde dk-layoutet i evdev.xml. Tilføj manuelt.")
    sys.exit(0)

with open(path, "w") as f:
    f.write(new_content)
print("    swerty tilføjet til evdev.xml.")
PYEOF
fi

echo "==> Aktiverer layoutet for den aktuelle bruger..."
SUDO_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
if [ -n "$SUDO_USER" ] && [ -n "$SUDO_USER_HOME" ]; then
    # Find brugerens aktive D-Bus session
    DBUS_ADDR=$(sudo -u "$SUDO_USER" bash -c '
        for pid in $(pgrep -u "$USER" gnome-session dbus-daemon 2>/dev/null); do
            addr=$(cat /proc/$pid/environ 2>/dev/null | tr "\0" "\n" | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2-)
            if [ -n "$addr" ]; then echo "$addr"; break; fi
        done
    ')
    if [ -n "$DBUS_ADDR" ]; then
        sudo -u "$SUDO_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" \
            gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'dk+swerty')]"
        echo "    Layout aktiveret for bruger: $SUDO_USER"
    else
        # Ingen aktiv session — skriv direkte til dconf-filen
        DCONF_DIR="$SUDO_USER_HOME/.config/dconf"
        mkdir -p "$DCONF_DIR"
        sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'dk+swerty')]" 2>/dev/null || \
        python3 -c "
import subprocess, os
db = '$DCONF_DIR/user'
subprocess.run(['dconf', 'load', '/org/gnome/desktop/input-sources/'],
    input=b\"[/]\\nsources=[('xkb', 'dk+swerty')]\\n\",
    env={**os.environ, 'HOME': '$SUDO_USER_HOME', 'USER': '$SUDO_USER'})
" 2>/dev/null || true
        echo "    Layout sat for bruger: $SUDO_USER (træder i kraft ved næste login)"
    fi
else
    echo "    Kunne ikke bestemme bruger. Kør manuelt efter login:"
    echo "    gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'dk+swerty')]\""
fi

echo "==> Aktiverer layoutet ved login-skærmen (GDM)..."

# Metode 1: /etc/default/keyboard — bruges af GDM og konsol
cat > /etc/default/keyboard <<EOF
XKBMODEL="pc105"
XKBLAYOUT="dk"
XKBVARIANT="swerty"
XKBOPTIONS=""
BACKSPACE="guess"
EOF
dpkg-reconfigure -f noninteractive keyboard-configuration 2>/dev/null || true
echo "    /etc/default/keyboard opdateret."

# Metode 2: GDM's egne dconf-indstillinger
GDM_DCONF_DIR="/var/lib/gdm3/.config/dconf"
GDM_DCONF_PROFILE="/etc/dconf/profile/gdm"
GDM_DCONF_DB="/etc/dconf/db/gdm.d"

mkdir -p "$GDM_DCONF_DB"
cat > "$GDM_DCONF_DB/00-keyboard" <<EOF
[org/gnome/desktop/input-sources]
sources=[('xkb', 'dk+swerty')]
EOF

# Sørg for at gdm-profilen peger på databasen
if [ ! -f "$GDM_DCONF_PROFILE" ]; then
    mkdir -p "$(dirname "$GDM_DCONF_PROFILE")"
    cat > "$GDM_DCONF_PROFILE" <<EOF
user-db:user
system-db:gdm
EOF
fi

dconf update 2>/dev/null || true
echo "    GDM dconf-indstillinger opdateret."

echo ""
echo "Swerty-layoutet er installeret — også ved login-skærmen."
echo "Log ud og ind igen (eller genstart GDM: sudo systemctl restart gdm) for at aktivere."

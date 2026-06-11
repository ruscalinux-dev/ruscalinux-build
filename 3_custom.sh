#!/bin/sh
set -e

# COPIA DEI PACCHETTI DA LOCAL PER ESSERE INSTALLATI DURANTE LA FASE DI BUILD
# adwaita-prugna, ruscalinux-backgrounds-it
cp local/extra_debs/*.deb ruscalinux/config/packages.chroot/

# IMPOSTAZIONE splash.png BINARY
mkdir -p ruscalinux/config/includes.binary/boot/grub/
mkdir -p ruscalinux/config/includes.binary/isolinux/
cp local/grub/splash.png ruscalinux/config/includes.binary/boot/grub/
cp local/isolinux/splash.png ruscalinux/config/includes.binary/isolinux/

# NOME E VERSIONE DEL SISTEMA OPERATIVO
mkdir -p ruscalinux/config/includes.chroot_after_packages/etc/
cat <<EOF > ruscalinux/config/includes.chroot_after_packages/etc/os-release
PRETTY_NAME="RuscaLinux 1.99"
NAME="RuscaLinux"
VERSION_ID="1.99"
VERSION="1.99"
VERSION_CODENAME=trixie
ID=ruscalinux
ID_LIKE=debian
LOGO="ruscalinux-logo"
HOME_URL="https://www.ruscalinux.org/"
SUPPORT_URL="https://www.ruscalinux.org/support"
BUG_REPORT_URL="https://bugs.ruscalinux.org/"
EOF

# ---------------------------------------------------------------------------
# FIX: NOME UTENTE E PASSWORD NELLA SCHERMATA DI LOGIN
mkdir -p ruscalinux/config/includes.chroot_after_packages/etc/live/config.conf.d/
echo 'LIVE_USER_FULLNAME="RuscaLinux Live user"
LIVE_USER_DEFAULT_PASSWORD="live"' > ruscalinux/config/includes.chroot_after_packages/etc/live/config.conf.d/99-ruscalinux-user.conf

# Sovrascrive i banner testuali di sistema usati da GDM come fallback
echo "RuscaLinux 1.99  \n \l" > ruscalinux/config/includes.chroot_after_packages/etc/issue
echo "RuscaLinux 1.99 " > ruscalinux/config/includes.chroot_after_packages/etc/issue.net

# COPIA DEL LOGO PER GNOME-INITIAL-SETUP E PANNELLO INFO
mkdir -p ruscalinux/config/includes.chroot_after_packages/usr/share/icons/hicolor/scalable/apps/
cp local/ruscalinux-logo.svg ruscalinux/config/includes.chroot_after_packages/usr/share/icons/hicolor/scalable/apps/ruscalinux-logo.svg

# Fallback PNG (usa quello di plymouth)
mkdir -p ruscalinux/config/includes.chroot_after_packages/usr/share/icons/hicolor/256x256/apps/
cp local/ruscalinux-logo.png ruscalinux/config/includes.chroot_after_packages/usr/share/icons/hicolor/256x256/apps/ruscalinux-logo.png

# IMPOSTA SFONDI PREDEFINITI DI GNOME E PERSONALIZZAZIONI
# Disabilita anche le notifiche di aggiornamento di gnome-software (sessione live e installata)
mkdir -p ruscalinux/config/includes.chroot_after_packages/usr/share/glib-2.0/schemas
cat <<EOF > ruscalinux/config/includes.chroot_after_packages/usr/share/glib-2.0/schemas/99_ruscalinux-backgrounds-it.gschema.override
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/ruscalinux-backgrounds/ruscalinux-wallpaper-light-3840x2160.png'
picture-uri-dark='file:///usr/share/backgrounds/ruscalinux-backgrounds/ruscalinux-wallpaper-dark-3840x2160.png'

[org.gnome.desktop.screensaver]
picture-uri='file:///usr/share/backgrounds/ruscalinux-backgrounds/ruscalinux-wallpaper-light-3840x2160.png'

[org.gnome.desktop.interface]
icon-theme='Adwaita-Prugna'
accent-color='slate'

[org.gnome.software]
allow-updates=false
download-updates=false
download-updates-notify=false

[org.gnome.shell]
disable-user-extensions=false

EOF

mkdir -p ruscalinux/config/hooks/normal/
cat <<EOF > ruscalinux/config/hooks/normal/9999-compile-schemas.hook.chroot
#!/bin/sh
glib-compile-schemas /usr/share/glib-2.0/schemas/
EOF

# ---------------------------------------------------------------------------
# GNOME INITIAL SETUP — nessun vendor.conf: le pagine keyboard e timezone
# vengono mostrate normalmente al primo avvio del sistema installato.
# gnome-initial-setup in new-user mode (nessun utente presente, grazie alla
# cancellazione dell'utente provvisorio nel postinstall) le presenta sempre.
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# FIX A — /usr/lib/os-release (target reale del symlink Debian)
# Senza questo, GDM/gnome-shell che leggono /usr/lib/os-release
# vedono ancora "Debian GNU/Linux 13 (trixie)"
# ---------------------------------------------------------------------------
mkdir -p ruscalinux/config/includes.chroot_after_packages/usr/lib/
cat <<EOF > ruscalinux/config/includes.chroot_after_packages/usr/lib/os-release
PRETTY_NAME="RuscaLinux 1.99"
NAME="RuscaLinux"
VERSION_ID="1.99"
VERSION="1.99"
VERSION_CODENAME=trixie
ID=ruscalinux
ID_LIKE=debian
LOGO="ruscalinux-logo"
HOME_URL="https://www.ruscalinux.org/"
SUPPORT_URL="https://www.ruscalinux.org/support"
BUG_REPORT_URL="https://bugs.ruscalinux.org/"
EOF

# ---------------------------------------------------------------------------
# FIX B — dconf dedicato per GDM (sovrascrive desktop-base)
# La gschema override vale per utenti normali, ma GDM usa il proprio
# profilo dconf: serve un file in /etc/dconf/db/gdm.d/ compilato
# con `dconf update` per forzare il logo nella schermata di login
# ---------------------------------------------------------------------------
mkdir -p ruscalinux/config/includes.chroot_after_packages/etc/dconf/profile/
cat <<'EOF' > ruscalinux/config/includes.chroot_after_packages/etc/dconf/profile/gdm
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF

# ---------------------------------------------------------------------------
# FIX C — Hook post-schema: aggiorna cache icone e compila dconf
# Deve girare DOPO 9999-compile-schemas, da cui il suffisso -zz
# - gtk-update-icon-cache: permette a gnome-initial-setup di trovare
#   l'icona "ruscalinux-logo" (letta tramite LOGO= in os-release)
# - dconf update: compila i file in /etc/dconf/db/gdm.d/ nel database
#   binario usato da GDM a runtime
# ---------------------------------------------------------------------------
cat <<'EOF' > ruscalinux/config/hooks/normal/9999-zz-branding-finalize.hook.chroot
#!/bin/sh
set -e

# Forza i permessi in modo che l'utente limitato "gdm" possa leggere il logo
chmod 644 /usr/share/icons/hicolor/scalable/apps/ruscalinux-logo.svg || true
chmod 644 /usr/share/icons/hicolor/256x256/apps/ruscalinux-logo.png || true

# Rigenera la cache delle icone hicolor
gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null || true

# Compila il database dconf per GDM (fix logo schermata di login)
dconf update 2>/dev/null || true
EOF
chmod +x ruscalinux/config/hooks/normal/9999-zz-branding-finalize.hook.chroot

# ---------------------------------------------------------------------------
# FIX 1 — GRUB BACKGROUND TRAMITE DROP-IN (evita il conflitto conffile)
# ---------------------------------------------------------------------------
mkdir -p ruscalinux/config/includes.chroot_after_packages/boot/grub/
mkdir -p ruscalinux/config/includes.chroot_after_packages/etc/default/grub.d/
cp local/splash.png ruscalinux/config/includes.chroot_after_packages/boot/grub/
echo "GRUB_BACKGROUND=/boot/grub/splash.png" \
    > ruscalinux/config/includes.chroot_after_packages/etc/default/grub.d/99-ruscalinux.cfg

# ---------------------------------------------------------------------------
# FIX 3 — LOCALE, KEYBOARD AND TIMEZONE: English only
#           The system is in English (en_US.UTF-8, US keyboard, UTC timezone).
#           Both in the live environment and the installed system.
# ---------------------------------------------------------------------------
cat <<'EOF' > ruscalinux/config/hooks/normal/0010-locale-multi.hook.chroot
#!/bin/sh
set -e

# 1) Enable all 12 supported locales in locale.gen
LOCALES="
en_US.UTF-8 UTF-8
es_ES.UTF-8 UTF-8
fr_FR.UTF-8 UTF-8
de_DE.UTF-8 UTF-8
pt_BR.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
ar_SA.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
hi_IN.UTF-8 UTF-8
bn_BD.UTF-8 UTF-8
id_ID.UTF-8 UTF-8
ur_PK.UTF-8 UTF-8
it_IT.UTF-8 UTF-8
ja_JP.UTF-8 UTF-8
pl_PL.UTF-8 UTF-8
nl_NL.UTF-8 UTF-8
cs_CZ.UTF-8 UTF-8
sk_SK.UTF-8 UTF-8
ro_RO.UTF-8 UTF-8
hu_HU.UTF-8 UTF-8
sv_SE.UTF-8 UTF-8
nb_NO.UTF-8 UTF-8
da_DK.UTF-8 UTF-8
fi_FI.UTF-8 UTF-8
el_GR.UTF-8 UTF-8
bg_BG.UTF-8 UTF-8
uk_UA.UTF-8 UTF-8
hr_HR.UTF-8 UTF-8
sr_RS.UTF-8 UTF-8
tr_TR.UTF-8 UTF-8
ca_ES.UTF-8 UTF-8
lt_LT.UTF-8 UTF-8
lv_LV.UTF-8 UTF-8
et_EE.UTF-8 UTF-8
sl_SI.UTF-8 UTF-8
pt_PT.UTF-8 UTF-8
gl_ES.UTF-8 UTF-8
eu_ES.UTF-8 UTF-8
ko_KR.UTF-8 UTF-8
zh_TW.UTF-8 UTF-8
vi_VN.UTF-8 UTF-8
th_TH.UTF-8 UTF-8
fa_IR.UTF-8 UTF-8
ta_IN.UTF-8 UTF-8
te_IN.UTF-8 UTF-8
mr_IN.UTF-8 UTF-8
pa_IN.UTF-8 UTF-8
ms_MY.UTF-8 UTF-8
sw_KE.UTF-8 UTF-8
"

# Comment out any currently active locales
sed -i 's/^\([^#].*\)/# \1/' /etc/locale.gen || true

# Uncomment or append each locale
for LOCALE_LINE in $(echo "$LOCALES" | grep -v '^$'); do
    LOCALE=$(echo "$LOCALE_LINE" | awk '{print $1}')
    if grep -q "^# *${LOCALE}" /etc/locale.gen; then
        sed -i "s|^# *${LOCALE} UTF-8|${LOCALE} UTF-8|" /etc/locale.gen
    else
        echo "${LOCALE} UTF-8" >> /etc/locale.gen
    fi
done
locale-gen

# 2) Set en_US.UTF-8 as system default locale
cat > /etc/default/locale <<LOC
LANG=en_US.UTF-8
LOC
update-locale LANG=en_US.UTF-8 || true

# 3) US keyboard
cat > /etc/default/keyboard <<KBD
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
KBD

# 4) UTC timezone
echo "UTC" > /etc/timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
EOF
chmod +x ruscalinux/config/hooks/normal/0010-locale-multi.hook.chroot

# ===========================================================================
# FIX 3-BIS — FORCE ENGLISH FOR GDM AND GNOME-INITIAL-SETUP
# ===========================================================================

# 1) /etc/locale.conf — read by systemd at boot, propagated to services
cat > ruscalinux/config/includes.chroot_after_packages/etc/locale.conf <<EOF
LANG=en_US.UTF-8
EOF

# 2) /etc/default/locale — read by Debian and pam_env
cat > ruscalinux/config/includes.chroot_after_packages/etc/default/locale <<EOF
LANG=en_US.UTF-8
EOF

# 3) /etc/environment — NON impostare LANG qui: pam_env lo propagherebbe a
#    TUTTE le sessioni PAM sovrascrivendo la lingua scelta dall'utente in
#    gnome-initial-setup. Il default di sistema è già in /etc/default/locale.

# 4) Drop-in gdm.service rimosso: forzare LANG nel processo GDM impedirebbe
#    a gnome-initial-setup di avviarsi nella lingua scelta dall'utente.
#    Il default di sistema (en_US.UTF-8 via /etc/default/locale) è sufficiente.

# 5) AccountsService pre-populated for Debian-gdm and gnome-initial-setup
mkdir -p ruscalinux/config/includes.chroot_after_packages/var/lib/AccountsService/users/

cat > ruscalinux/config/includes.chroot_after_packages/var/lib/AccountsService/users/Debian-gdm <<EOF
[User]
Language=en_US.UTF-8
FormatsLocale=en_US.UTF-8
XSession=gnome
SystemAccount=true
EOF

cat > ruscalinux/config/includes.chroot_after_packages/var/lib/AccountsService/users/gnome-initial-setup <<EOF
[User]
XSession=gnome
SystemAccount=true
EOF

# 6) Hook that ensures en_US.UTF-8 is generated and localectl is consistent
cat > ruscalinux/config/hooks/normal/0011-force-english-locale.hook.chroot <<'EOF'
#!/bin/sh
set -e

# Fallback: ensure en_US.UTF-8 is present (hook 0010 should have done this already)
if [ -f /etc/locale.gen ]; then
    grep -q '^en_US.UTF-8' /etc/locale.gen || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
    locale-gen
fi

# System default is English; users can choose their language in GNOME Settings
update-locale LANG=en_US.UTF-8 || true

if command -v localectl >/dev/null 2>&1; then
    localectl set-locale LANG=en_US.UTF-8 || true
fi
EOF
chmod +x ruscalinux/config/hooks/normal/0011-force-english-locale.hook.chroot

# 7) (rimosso) l'override org.gnome.system.locale region='en_US.UTF-8' è stato
# eliminato: in gnome-control-center la sezione "Regione e lingua" legge questo
# valore e, se forzato a sistema, può impedire all'utente di cambiare i formati
# data/ora/numero. Il file 98_ruscalinux-locale.gschema.override non viene più
# creato; la lingua di sistema rimane quella impostata nel Debian Installer
# (o en_US.UTF-8 di fallback), che l'utente può sovrascrivere liberamente.

# ---------------------------------------------------------------------------
# TEMA PLYMOUTH PERSONALIZZATO RUSCALINUX
# ---------------------------------------------------------------------------
PLYMOUTH_THEME_DIR="ruscalinux/config/includes.chroot_after_packages/usr/share/plymouth/themes/ruscalinux"
mkdir -p "$PLYMOUTH_THEME_DIR"

cp local/ruscalinux-logo.png "$PLYMOUTH_THEME_DIR/logo.png"

cat <<'EOF' > "$PLYMOUTH_THEME_DIR/ruscalinux.plymouth"
[Plymouth Theme]
Name=RuscaLinux 
Description=Schermata di avvio ufficiale di RuscaLinux 
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/ruscalinux
ScriptFile=/usr/share/plymouth/themes/ruscalinux/ruscalinux.script
EOF

cat <<'EOF' > "$PLYMOUTH_THEME_DIR/ruscalinux.script"
# ── Colori brand RuscaLinux ──────────────────────────────────────────────
BG_R = 0.05;   BG_G = 0.01;   BG_B = 0.03;   # ~#0D0208
BAR_R = 0.545; BAR_G = 0.082; BAR_B = 0.220;  # #8B1538

# ── Sfondo pieno ─────────────────────────────────────────────────────────
Window.SetBackgroundTopColor(BG_R, BG_G, BG_B);
Window.SetBackgroundBottomColor(BG_R, BG_G, BG_B);

# ── Logo ─────────────────────────────────────────────────────────────────
logo.image  = Image("logo.png");
logo.width  = logo.image.GetWidth();
logo.height = logo.image.GetHeight();
logo.x      = Window.GetWidth()  / 2 - logo.width  / 2;
logo.y      = Window.GetHeight() / 2 - logo.height / 2 - 40;

logo.sprite = Sprite();
logo.sprite.SetImage(logo.image);
logo.sprite.SetX(logo.x);
logo.sprite.SetY(logo.y);
logo.sprite.SetZ(10);

# ── Barra di avanzamento ──────────────────────────────────────────────────
BAR_FULL_W = Math.Int(Window.GetWidth() * 0.45);
BAR_H      = 4;
BAR_X      = Math.Int((Window.GetWidth() - BAR_FULL_W) / 2);
BAR_Y      = Window.GetHeight() - 55;

bar_bg.image = Image(BAR_FULL_W, BAR_H);
bar_bg.image.Fill(0.15, 0.05, 0.08, 0.5);
bar_bg.sprite = Sprite();
bar_bg.sprite.SetImage(bar_bg.image);
bar_bg.sprite.SetX(BAR_X);
bar_bg.sprite.SetY(BAR_Y);
bar_bg.sprite.SetZ(9);

bar.sprite = Sprite();
bar.sprite.SetX(BAR_X);
bar.sprite.SetY(BAR_Y);
bar.sprite.SetZ(10);

fun plymouth_boot_progress_callback(time, progress) {
    fill_w = Math.Int(BAR_FULL_W * progress);
    if (fill_w < 2) fill_w = 2;
    bar.image = Image(fill_w, BAR_H);
    bar.image.Fill(BAR_R, BAR_G, BAR_B, 1.0);
    bar.sprite.SetImage(bar.image);
}
Plymouth.SetBootProgressFunction(plymouth_boot_progress_callback);

fun plymouth_quit_callback() {
    logo.sprite.SetOpacity(0);
    bar.sprite.SetOpacity(0);
    bar_bg.sprite.SetOpacity(0);
}
Plymouth.SetQuitFunction(plymouth_quit_callback);

# ── Animazione pulsazione logo (luminosità) ───────────────────────────────
# refresh_callback è chiamata ~50 volte al secondo dal Plymouth.
# Usiamo un contatore che incrementa di 1 per frame; con 50fps e 200 frame
# totali il ciclo completo dura 4 secondi (salita 2s, discesa 2s).
# L'opacità oscilla tra 0.35 (scuro) e 1.0 (piena luce).
anim_frame     = 0;
anim_direction = 1;     # +1 = sale, -1 = scende
ANIM_STEPS     = 100;   # passi per metà ciclo (salita O discesa)
ANIM_LOW       = 0.35;
ANIM_HIGH      = 1.0;
ANIM_RANGE     = ANIM_HIGH - ANIM_LOW;   # 0.65

fun refresh_callback() {
    anim_frame = anim_frame + anim_direction;
    if (anim_frame >= ANIM_STEPS) {
        anim_frame     = ANIM_STEPS;
        anim_direction = -1;
    } else if (anim_frame <= 0) {
        anim_frame     = 0;
        anim_direction = 1;
    }
    # t in [0 .. 1]: quanto siamo avanzati nel semi-ciclo corrente
    t = anim_frame / ANIM_STEPS;
    # Curva smooth (ease-in/out): 3t² − 2t³  →  più naturale di una rampa lineare
    smooth = t * t * (3.0 - 2.0 * t);
    logo.sprite.SetOpacity(ANIM_LOW + smooth * ANIM_RANGE);
}
Plymouth.SetRefreshFunction(refresh_callback);
EOF

cat <<'EOF' > ruscalinux/config/hooks/normal/9990-set-plymouth-theme.hook.chroot
#!/bin/sh
set -e

if ! dpkg -l plymouth 2>/dev/null | grep -q '^ii'; then
    echo "AVVISO: plymouth non installato nel chroot, skip." >&2
    exit 0
fi

update-alternatives --install \
    /usr/share/plymouth/themes/default.plymouth \
    default.plymouth \
    /usr/share/plymouth/themes/ruscalinux/ruscalinux.plymouth \
    200 || true

plymouth-set-default-theme -R ruscalinux

exit 0
EOF
chmod +x ruscalinux/config/hooks/normal/9990-set-plymouth-theme.hook.chroot

echo "plymouth"        >> ruscalinux/config/package-lists/ruscalinux.list.chroot
echo "plymouth-themes" >> ruscalinux/config/package-lists/ruscalinux.list.chroot

# SOSTITUZIONE PROFONDA DEL LOGO DEBIAN E DEL PIEDONE GNOME CON QUELLO DI RUSCALINUX
mkdir -p ruscalinux/config/includes.chroot_after_packages/usr/share/icons/vendor/scalable/emblems/
cp local/emblem-vendor.svg ruscalinux/config/includes.chroot_after_packages/usr/share/icons/vendor/scalable/emblems/

mkdir -p ruscalinux/config/hooks/normal/
cat <<'EOF' > ruscalinux/config/hooks/normal/9991-replace-debian-logos.hook.chroot
#!/bin/sh
set -e

gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
gtk-update-icon-cache -f -t /usr/share/icons/vendor || true

# 1. Sostituisce brutalmente tutti i loghi, intercettando ogni SVG/PNG nelle cartelle login di Debian
if [ -d /usr/share/desktop-base ]; then
    find -L /usr/share/desktop-base -type f \( -name "*logo*.svg" -o -name "*logo*.png" -o -path "*/login/*.svg" -o -path "*/login/*.png" \) | while read -r f; do
        if echo "$f" | grep -q "\.svg$"; then
            cp /usr/share/icons/hicolor/scalable/apps/ruscalinux-logo.svg "$f" 2>/dev/null || true
        elif echo "$f" | grep -q "\.png$"; then
            cp /usr/share/plymouth/themes/ruscalinux/logo.png "$f" 2>/dev/null || true
        fi
    done
fi

# 2. Sostituisce il "piedone" di GNOME (start-here e gnome-logo) in tutti i temi di icone
if [ -d /usr/share/icons ]; then
    find -L /usr/share/icons -type f \( -name "start-here*.svg" -o -name "start-here*.png" -o -name "gnome-logo*.svg" -o -name "gnome-logo*.png" \) | while read -r f; do
        if echo "$f" | grep -q "\.svg$"; then
            cp /usr/share/icons/hicolor/scalable/apps/ruscalinux-logo.svg "$f" 2>/dev/null || true
        elif echo "$f" | grep -q "\.png$"; then
            cp /usr/share/plymouth/themes/ruscalinux/logo.png "$f" 2>/dev/null || true
        fi
    done
fi
EOF
chmod +x ruscalinux/config/hooks/normal/9991-replace-debian-logos.hook.chroot

# ---------------------------------------------------------------------------
# FIX 4 — BANNER GRAFICO INSTALLER GTK (vinaccia, "RuscaLinux 1.99")
# ---------------------------------------------------------------------------
BANNER_SRC="local/banner.png"

if [ ! -f "$BANNER_SRC" ]; then
    echo "ERRORE: $BANNER_SRC non trovato! Assicurati di aver salvato l'immagine generata."
    exit 1
fi

# Percorso primario trixie
mkdir -p ruscalinux/config/includes.installer/usr/share/desktop-base/trixie-theme/installer/
cp "$BANNER_SRC" ruscalinux/config/includes.installer/usr/share/desktop-base/trixie-theme/installer/banner.png

# Percorso fallback emerald
mkdir -p ruscalinux/config/includes.installer/usr/share/desktop-base/emerald-theme/installer/
cp "$BANNER_SRC" ruscalinux/config/includes.installer/usr/share/desktop-base/emerald-theme/installer/banner.png

# Percorso fallback homeworld
mkdir -p ruscalinux/config/includes.installer/usr/share/desktop-base/homeworld-theme/installer/
cp "$BANNER_SRC" ruscalinux/config/includes.installer/usr/share/desktop-base/homeworld-theme/installer/banner.png

# Copia anche sul CD in modo che l'early_command possa usarla
cp "$BANNER_SRC" ruscalinux/config/includes.binary/banner_ruscalinux.png

# Hook installer — sostituisce banner.png via symlink attivo a runtime
mkdir -p ruscalinux/config/hooks/installer/
cat <<'EOF' > ruscalinux/config/hooks/installer/9001-banner.hook.installer
#!/bin/sh
set -e
BANNER_SRC="/cdrom/banner_ruscalinux.png"
[ -f "$BANNER_SRC" ] || exit 0
# Sovrascrive tutti i banner.png nell'albero desktop-base, symlink inclusi
find -L /usr/share/desktop-base -name "banner.png" -path "*/installer/*" 2>/dev/null | \
    while read -r f; do
        cp "$BANNER_SRC" "$f" 2>/dev/null || true
    done
exit 0
EOF
chmod +x ruscalinux/config/hooks/installer/9001-banner.hook.installer

# ===========================================================================
# FIX — HOSTNAME PREDEFINITO DAL MODELLO DELLA MACCHINA (DMI / SMBIOS)
# ===========================================================================
# Il debian-installer usa "debian" come hostname predefinito perché la rete
# è disabilitata. Leggiamo il modello dal firmware e lo proponiamo come
# default. L'utente può comunque modificarlo nella schermata dell'installer.
# ---------------------------------------------------------------------------
cat > ruscalinux/config/includes.binary/set-hostname.sh <<'EOF'
#!/bin/sh
# Chiamato da preseed/early_command. Legge il modello da DMI/SMBIOS e
# imposta netcfg/get_hostname + netcfg/hostname tramite debconf-set-selections.
set -e

PRODUCT=""
for f in /sys/class/dmi/id/product_family \
         /sys/class/dmi/id/product_name \
         /sys/class/dmi/id/board_name; do
    [ -r "$f" ] || continue
    val=$(head -1 "$f" 2>/dev/null | tr -d '\n')
    case "$val" in
        ""|" "|"To Be Filled By O.E.M."|"To be filled by O.E.M."|\
        "System Product Name"|"System Version"|"Default string"|\
        "Not Specified"|"Not Applicable"|"None"|"Unknown"|"OEM")
            continue
            ;;
    esac
    PRODUCT="$val"
    break
done

HOST=""
if [ -n "$PRODUCT" ]; then
    # minuscolo, solo [a-z0-9], niente spazi/trattini, max 30 caratteri
    HOST=$(printf '%s' "$PRODUCT" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -cd 'a-z0-9' \
        | cut -c1-30)
    # se inizia con cifra, anteponi "pc"
    case "$HOST" in
        [0-9]*) HOST="pc${HOST}" ;;
    esac
fi

[ -z "$HOST" ] && HOST=ruscalinux

echo "d-i netcfg/get_hostname string $HOST" | debconf-set-selections
echo "d-i netcfg/hostname     string $HOST" | debconf-set-selections
echo "d-i netcfg/get_domain   string"        | debconf-set-selections
EOF
chmod +x ruscalinux/config/includes.binary/set-hostname.sh

# ---------------------------------------------------------------------------
# INSTALLER GRAFICO DEBIAN — CONFIGURAZIONE OFFLINE SEMI-AUTOMATICA
# ---------------------------------------------------------------------------
mkdir -p ruscalinux/config/includes.binary/

cat <<'EOF' > ruscalinux/config/includes.binary/preseed.cfg
# =============================================================
#  ruscalinux — Preseed for semi-automatic graphical installation
#  Language: English | Mode: Offline
# =============================================================
# NOTE: language/keyboard/timezone are NOT pre-set via kernel cmdline,
#       so the installer will prompt the user for these choices.
#       Only post-CD-mount settings are configured here.

# --- debconf priority HIGH (default GTK installer) ---
d-i debconf/priority select high

# --- Keyboard confirmation (redundant with keymap=us from cmdline) ---
d-i console-setup/ask_detect boolean false
d-i keyboard-configuration/layoutcode string us
d-i keyboard-configuration/variantcode string
d-i keyboard-configuration/xkb-keymap select us
d-i keymap select us

# --- Timezone UTC ---
d-i time/zone string UTC
d-i clock-setup/utc boolean true
d-i clock-setup/ntp boolean false

# --- Rete: disabilitata ---
d-i netcfg/enable boolean false
d-i netcfg/dhcp_options select Do not configure the network at this time
d-i netcfg/get_hostname string ruscalinux
d-i netcfg/hostname string ruscalinux
d-i netcfg/get_domain string

# --- Mirror APT ---
d-i mirror/country string manual
d-i mirror/http/hostname string 127.0.0.1
d-i mirror/http/directory string /
d-i mirror/http/proxy string
d-i apt-setup/use_mirror boolean false
d-i apt-setup/no_mirror boolean true
d-i apt-setup/cdrom/set-first boolean true
d-i apt-setup/services-select multiselect

# --- Partizionamento ---
# Metodo: guided (partman-auto gestisce il disco automaticamente).
# La ricetta NON è preseedata: l'installer presenterà all'utente le tre opzioni:
#   • Tutto in una partizione          (atomic)
#   • Partizione /home separata        (home)
#   • Partizioni /home, /var, /tmp     (multi)
d-i partman-auto/method string regular
d-i partman/default_filesystem string ext4
d-i partman/confirm boolean false
d-i partman/confirm_nooverwrite boolean false
d-i partman/confirm_write_new_label boolean false
d-i partman/choose_partition select finish

# --- Account utente ---
# Disabilita l'account root diretto
d-i passwd/root-login boolean false
# Crea un utente fittizio in background in modo silente
d-i passwd/make-user boolean true
d-i passwd/user-fullname string Temporary User
d-i passwd/username string oem
d-i passwd/user-password password oem1234
d-i passwd/user-password-again password oem1234
d-i passwd/user-default-groups string audio cdrom dip floppy video plugdev netdev sudo

# --- Gestione conffile dpkg + hostname auto da DMI ---
d-i preseed/early_command string \
    mkdir -p /etc/apt/apt.conf.d/ && \
    printf 'Dpkg::Options {"--force-confdef";"--force-confold";};\n' \
    > /etc/apt/apt.conf.d/99force-confold && \
    sh /cdrom/set-hostname.sh

# --- Selezione pacchetti ---
d-i pkgsel/upgrade select none
d-i pkgsel/update-policy select none
d-i pkgsel/include string

# --- Bootloader GRUB ---
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev string default

# --- Branding installer ---
d-i debian-installer/title string RuscaLinux 1.99 

# ---------------------------------------------------------------------------
# late_command
# ---------------------------------------------------------------------------
d-i preseed/late_command string \
    cp /cdrom/ruscalinux-postinstall.sh /target/tmp/ruscalinux-postinstall.sh ; \
    chmod +x /target/tmp/ruscalinux-postinstall.sh ; \
    in-target /tmp/ruscalinux-postinstall.sh || true

# --- Fine installazione ---
# finish-install/reboot_in_progress NON preseedato: l'installer GTK
# mostrerà il dialog "Installazione completata" e aspetterà il click
# su Continua prima di spegnere (dà il tempo di rimuovere la USB).
d-i finish-install/keep-consoles boolean false
d-i debian-installer/exit/poweroff boolean true
EOF

# ---------------------------------------------------------------------------
# Script post-installazione (chiamato dal late_command)
# ---------------------------------------------------------------------------
cat <<'POSTINSTALL' > ruscalinux/config/includes.binary/ruscalinux-postinstall.sh
#!/bin/sh
set -e

# ---------------------------------------------------------------------------
# TEMA PLYMOUTH — forza la selezione e rigenera l'initramfs nel sistema installato
# Necessario perché il Debian Installer rigenera l'initramfs PRIMA di late_command,
# quindi dobbiamo farlo di nuovo alla fine per avere il tema corretto sul disco.
# ---------------------------------------------------------------------------
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    update-alternatives --install \
        /usr/share/plymouth/themes/default.plymouth \
        default.plymouth \
        /usr/share/plymouth/themes/ruscalinux/ruscalinux.plymouth \
        200 2>/dev/null || true
    plymouth-set-default-theme ruscalinux
fi

# Rigenera l'initramfs per tutti i kernel installati con il tema corretto
update-initramfs -u -k all || true

# ===========================================================================
# HOSTNAME — override diretto, sovrascrive qualunque cosa abbia impostato
# il Debian Installer (incluso il fallback "debian" di netcfg).
# ===========================================================================
echo "ruscalinux" > /etc/hostname
if grep -q "^127\.0\.1\.1" /etc/hosts; then
    sed -i "s/^127\.0\.1\.1.*/127.0.1.1\truscalinux/" /etc/hosts
else
    echo "127.0.1.1\truscalinux" >> /etc/hosts
fi

# ===========================================================================
# MODALITÀ OEM: FORZA GNOME INITIAL SETUP COMPLETO AL PRIMO AVVIO
# ===========================================================================

# Rileva l'utente creato temporaneamente dal Debian Installer
IUSER=$(ls /home/ 2>/dev/null | grep -v lost+found | head -1)

if [ -n "$IUSER" ]; then
    echo ">>> Eliminazione utente provvisorio $IUSER per forzare GNOME Initial Setup..."
    # Elimina l'utente e la sua home directory
    userdel -r "$IUSER" 2>/dev/null || true
    
    # Elimina SOLO il profilo AccountsService dell'utente provvisorio
    rm -f "/var/lib/AccountsService/users/$IUSER" 2>/dev/null || true
fi

# Force GDM and GNOME Initial Setup to use English
mkdir -p /var/lib/AccountsService/users/

# GDM user on Debian is "Debian-gdm"
cat > /var/lib/AccountsService/users/Debian-gdm <<EOF
[User]
Language=en_US.UTF-8
XSession=gnome
SystemAccount=true
EOF

# System user used to launch GNOME Initial Setup at first boot
cat > /var/lib/AccountsService/users/gnome-initial-setup <<EOF
[User]
XSession=gnome
SystemAccount=true
EOF

# Preserva la lingua scelta dall'utente nel Debian Installer.
# Il Debian Installer ha già scritto LANG in /etc/default/locale;
# la sovrascrittura forzata a en_US.UTF-8 era la causa per cui GNOME
# rimaneva in inglese anche dopo aver impostato un'altra lingua.
# Sincronizziamo solo /etc/locale.conf (richiesto da systemd) con
# il valore scelto dall'installer, o en_US.UTF-8 come fallback sicuro.
INST_LANG=$(grep '^LANG=' /etc/default/locale 2>/dev/null | cut -d= -f2 | head -1)
[ -z "$INST_LANG" ] && INST_LANG="en_US.UTF-8"
printf 'LANG=%s\n' "$INST_LANG" > /etc/locale.conf

# ===========================================================================
# AUTOLOGIN PER IL PRIMO UTENTE REALE
# ===========================================================================
# L'utente viene creato da gnome-initial-setup al primo boot, quindi il suo
# username NON è noto in fase di installazione. Installiamo un servizio
# systemd "oneshot" che, ad ogni boot, controlla se esiste un utente "umano"
# (UID >= 1000) e, in caso affermativo, configura l'autologin in
# /etc/gdm3/daemon.conf. Dopo la prima esecuzione si auto-disabilita.
# ---------------------------------------------------------------------------
mkdir -p /usr/local/sbin
cat > /usr/local/sbin/ruscalinux-setup-autologin <<'AUTOSCRIPT'
#!/bin/sh
set -e

FLAG=/var/lib/ruscalinux/autologin.done
[ -f "$FLAG" ] && exit 0

# Trova il primo utente "umano" (UID >= 1000, < 65000), escluso nobody/gdm
USER=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65000 && $1 != "nobody" {print $1; exit}')
[ -z "$USER" ] && exit 0

# Configura GDM3
mkdir -p /etc/gdm3
CONF=/etc/gdm3/daemon.conf

if [ ! -f "$CONF" ]; then
    printf '[daemon]\n' > "$CONF"
fi

# Rimuove eventuali righe pregresse e riscrive la sezione [daemon]
sed -i '/^AutomaticLoginEnable\s*=/d; /^AutomaticLogin\s*=/d' "$CONF"
if grep -q '^\[daemon\]' "$CONF"; then
    sed -i "/^\[daemon\]/a AutomaticLoginEnable=true\nAutomaticLogin=$USER" "$CONF"
else
    printf '\n[daemon]\nAutomaticLoginEnable=true\nAutomaticLogin=%s\n' "$USER" >> "$CONF"
fi

# ---------------------------------------------------------------------------
# Propaga la lingua scelta in gnome-initial-setup al locale di sistema.
# g-i-s scrive Language= nell'AccountsService dell'utente al primo boot.
# Questo servizio gira Before=display-manager al secondo boot: aggiornando
# /etc/locale.conf PRIMA che GDM parta, la sessione autologin parte già
# nella lingua scelta dall'utente, senza dipendere dal meccanismo
# AccountsService→sessione di GDM (che con autologin può non attivarsi).
# ---------------------------------------------------------------------------
AS_FILE="/var/lib/AccountsService/users/$USER"
if [ -f "$AS_FILE" ]; then
    USER_LANG=$(grep '^Language=' "$AS_FILE" | cut -d= -f2 | head -1)
    if [ -n "$USER_LANG" ]; then
        printf 'LANG=%s\n' "$USER_LANG" > /etc/locale.conf
        printf 'LANG=%s\n' "$USER_LANG" > /etc/default/locale
        # Forza systemd-localed a rileggere il file aggiornato
        systemctl restart systemd-localed 2>/dev/null || true
    fi
fi

mkdir -p /var/lib/ruscalinux
touch "$FLAG"
# Disabilita il servizio dopo la prima esecuzione riuscita
systemctl disable ruscalinux-autologin.service 2>/dev/null || true
AUTOSCRIPT
chmod +x /usr/local/sbin/ruscalinux-setup-autologin

cat > /etc/systemd/system/ruscalinux-autologin.service <<'AUTOUNIT'
[Unit]
Description=Configura autologin GDM per il primo utente reale (RuscaLinux)
Before=display-manager.service
ConditionPathExists=!/var/lib/ruscalinux/autologin.done

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/ruscalinux-setup-autologin
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
AUTOUNIT

systemctl enable ruscalinux-autologin.service 2>/dev/null || true

# GRUB background + quiet splash via grub.d
# CRITICO: senza "splash" nel cmdline del kernel, Plymouth non mostra
# mai il tema grafico anche se l'initramfs lo contiene correttamente.
mkdir -p /etc/default/grub.d/
cat > /etc/default/grub.d/99-ruscalinux.cfg <<'GRUBCFG'
GRUB_BACKGROUND=/boot/grub/splash.png
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUBCFG
update-grub || true

# Disabilita repository e aggiornamenti automatici
echo "# Repository disabilitate da ruscalinux installer" > /etc/apt/sources.list
rm -f /etc/apt/sources.list.d/*.list
rm -f /etc/apt/sources.list.d/*.sources

systemctl disable apt-daily.timer         2>/dev/null || true
systemctl disable apt-daily-upgrade.timer 2>/dev/null || true
systemctl mask   apt-daily.service        2>/dev/null || true
systemctl mask   apt-daily-upgrade.service 2>/dev/null || true

if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
    printf 'APT::Periodic::Update-Package-Lists "0";\nAPT::Periodic::Unattended-Upgrade "0";\n' \
        > /etc/apt/apt.conf.d/20auto-upgrades
fi

echo ">>> Post-installazione ruscalinux  completata."
POSTINSTALL

chmod +x ruscalinux/config/includes.binary/ruscalinux-postinstall.sh

# --- Hook installer: forza uso del CD come sorgente APT ---
mkdir -p ruscalinux/config/hooks/installer/
cat <<'EOF' > ruscalinux/config/hooks/installer/9000-offline-apt.hook.installer
#!/bin/sh
set -e
if [ -f /etc/apt/sources.list ]; then
    grep -v "^deb http" /etc/apt/sources.list > /tmp/sources.list.clean || true
    mv /tmp/sources.list.clean /etc/apt/sources.list
fi
exit 0
EOF
chmod +x ruscalinux/config/hooks/installer/9000-offline-apt.hook.installer

# ---------------------------------------------------------------------------
# BANNER INSTALLER DEBIAN (Color Vinaccia + Testo)
# ---------------------------------------------------------------------------
# Creiamo la cartella che live-build inietta nell'installer
mkdir -p ruscalinux/config/includes.installer/usr/share/graphics/

# Copiamo il banner sovrascrivendo i loghi di default (chiaro e scuro)
cp local/banner.png ruscalinux/config/includes.installer/usr/share/graphics/logo_debian.png
cp local/banner.png ruscalinux/config/includes.installer/usr/share/graphics/logo_debian_dark.png

# ---------------------------------------------------------------------------
# IMPEDISCI L'INSTALLAZIONE DI FORTUNE ED EVENTUALI ALTRI PACCHETTI TRAMITE APT PREFERENCES
# ---------------------------------------------------------------------------
mkdir -p ruscalinux/config/includes.chroot_before_packages/etc/apt/preferences.d/
cat <<'EOF' > ruscalinux/config/includes.chroot_before_packages/etc/apt/preferences.d/99-exclude-packages
Package: fortune-mod
Pin: release *
Pin-Priority: -1
EOF

# ---------------------------------------------------------------------------
# NASCONDI TeXdoctk DAL MENU GNOME (applicazione inutile installata da texlive)
# ---------------------------------------------------------------------------
#mkdir -p ruscalinux/config/includes.chroot_after_packages/usr/share/applications/
#cat <<EOF > ruscalinux/config/includes.chroot_after_packages/usr/share/applications/texdoctk.desktop
#[Desktop Entry]
#NoDisplay=true
#EOF

# ---------------------------------------------------------------------------
# RIMUOVI GNOME-SOFTWARE (inutile: aggiornamenti e repository sono disabilitati)
# ---------------------------------------------------------------------------
cat <<'EOF' > ruscalinux/config/hooks/normal/9998-remove-gnome-software.hook.chroot
#!/bin/sh
set -e
apt-get remove --purge --assume-yes gnome-software gnome-software-common 2>/dev/null || true
apt-get autoremove --assume-yes 2>/dev/null || true
EOF
chmod +x ruscalinux/config/hooks/normal/9998-remove-gnome-software.hook.chroot

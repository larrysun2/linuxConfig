#!/usr/bin/env bash
set -euo pipefail

# --- Parámetros ---
USERNAME="${1:-user}"
PASSWORD="${2:-Vgvgvg12}"
APPIMAGE_NAME="Ultra-9.10.0-x86_64.AppImage"
APPIMAGE_URL="https://ultrascrapper.com/descargas/Ultra-9.10.0-x86_64.AppImage"

if [[ $EUID -ne 0 ]]; then
  echo "Ejecuta como root: sudo ./setup_min_xfce.sh <usuario> <clave>"
  exit 1
fi

echo "[1/8] Actualizando sistema…"
export DEBIAN_FRONTEND=noninteractive
apt update -y
apt upgrade -y

echo "[2/8] Creando usuario $USERNAME con sudo…"
if ! id -u "$USERNAME" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$USERNAME"
  echo "$USERNAME:$PASSWORD" | chpasswd
  usermod -aG sudo "$USERNAME"
fi

echo "[3/8] Instalando XFCE + XRDP…"
apt install -y xfce4 xfce4-goodies xorg dbus-x11 x11-xserver-utils xrdp wget ca-certificates

echo "[4/8] Configurando XRDP para XFCE…"
echo "startxfce4" > "/home/$USERNAME/.xsession"
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.xsession"

sed -i 's/^\(test -r \/etc\/X11\/Xsession.*\)$/# \1/g' /etc/xrdp/startwm.sh || true
sed -i '1i\export DESKTOP_SESSION=xfce\nexport XDG_SESSION_DESKTOP=xfce\nstartxfce4\nexit 0' /etc/xrdp/startwm.sh

adduser xrdp ssl-cert || true
systemctl enable xrdp
systemctl restart xrdp

echo "[5/8] Configurando NoSleep (evitar bloqueo/apagado de pantalla)…"
runuser -l "$USERNAME" -c 'mkdir -p ~/.config/autostart ~/.local/bin ~/Escritorio'

cat > "/home/$USERNAME/.local/bin/nosleep.sh" <<'EOS'
#!/usr/bin/env bash
sleep 2
xset s off
xset -dpms
xset s noblank
if command -v xfconf-query >/dev/null 2>&1; then
  xfconf-query -c xfce4-screensaver -p /saver/enabled -s false 2>/dev/null || true
  xfconf-query -c xfce4-screensaver -p /lock/enabled -s false 2>/dev/null || true
  xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/blank-on-ac -s 0 2>/dev/null || true
  xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-enabled -s false 2>/dev/null || true
fi
EOS
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.local/bin/nosleep.sh"
chmod +x "/home/$USERNAME/.local/bin/nosleep.sh"

cat > "/home/$USERNAME/.config/autostart/00-nosleep.desktop" <<EOS
[Desktop Entry]
Type=Application
Name=NoSleep
Exec=/home/$USERNAME/.local/bin/nosleep.sh
X-GNOME-Autostart-enabled=true
EOS
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.config/autostart/00-nosleep.desktop"

echo "[6/8] Descargando Ultra AppImage…"
runuser -l "$USERNAME" -c "wget -O ~/${APPIMAGE_NAME} '${APPIMAGE_URL}'"
runuser -l "$USERNAME" -c "chmod +x ~/${APPIMAGE_NAME}"

echo "[7/8] Creando lanzador en alta prioridad…"
cat > "/home/$USERNAME/Escritorio/Ultra-Alto-Prioridad.sh" <<EOS
#!/usr/bin/env bash
nohup nice -n -10 ionice -c 2 -n 0 ~/${APPIMAGE_NAME} --no-sandbox > ~/ultra.log 2>&1 &
EOS
chown "$USERNAME:$USERNAME" "/home/$USERNAME/Escritorio/Ultra-Alto-Prioridad.sh"
chmod +x "/home/$USERNAME/Escritorio/Ultra-Alto-Prioridad.sh"

cat > "/home/$USERNAME/Escritorio/Ultra-Alto-Prioridad.desktop" <<EOS
[Desktop Entry]
Type=Application
Name=Ultra (Alta prioridad)
Comment=Ejecuta Ultra AppImage con prioridad alta y --no-sandbox
Exec=/home/$USERNAME/Escritorio/Ultra-Alto-Prioridad.sh
Icon=utilities-terminal
Terminal=false
Categories=Utility;
EOS
chown "$USERNAME:$USERNAME" "/home/$USERNAME/Escritorio/Ultra-Alto-Prioridad.desktop"
chmod +x "/home/$USERNAME/Escritorio/Ultra-Alto-Prioridad.desktop"

echo "[8/8] Limpieza y finalización ✅"
echo "---------------------------------------------"
echo "Usuario creado: $USERNAME"
echo "Contraseña: $PASSWORD"
echo "Conexion RDP: IP del VPS (puerto 3389)"
echo "Ultra descargado: /home/$USERNAME/${APPIMAGE_NAME}"
echo "Lanzadores: Escritorio -> Ultra-Alto-Prioridad.sh y .desktop"
echo "---------------------------------------------"
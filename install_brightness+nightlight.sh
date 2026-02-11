#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 namar0x0309

# 1. Install dependencies (Check for YAD)
echo "Checking for dependencies..."
MISSING=()
for dep in yad redshift bc; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    MISSING+=("$dep")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "Missing: ${MISSING[*]}"
  sudo apt update || echo "Warning: apt update failed. Continuing with install attempt."
  sudo apt install -y "${MISSING[@]}"
else
  echo "All dependencies already installed."
fi

# 2. Create the executable script
mkdir -p ~/.local/bin
cat << 'EOF' > ~/.local/bin/redshift-slider.sh
#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 namar0x0309
KEY=12345
STATE_DIR="$HOME/.local/share/redshift-slider"
STATE_FILE="$STATE_DIR/state"
mkdir -p "$STATE_DIR"

if [ ! -f "$STATE_FILE" ]; then
  {
    echo "B_VAL=8"
    echo "T_VAL=45"
  } > "$STATE_FILE"
fi

load_state() {
  B_VAL=8
  T_VAL=45
  # shellcheck disable=SC1090
  . "$STATE_FILE" 2>/dev/null
}

save_state() {
  {
    echo "B_VAL=$B_VAL"
    echo "T_VAL=$T_VAL"
  } > "$STATE_FILE"
}

brightness_pane() {
  load_state
  yad --plug="$KEY" --tabnum=1 \
      --scale --min-value=1 --max-value=10 --value="$B_VAL" \
      --print-partial --title="Brightness" --text="Brightness" \
      --width=300 --height=50 \
      | while read -r B; do
          load_state
          B_VAL="$B"
          save_state
          BRIGHTNESS=$(echo "scale=2; $B_VAL/10" | bc -l)
          redshift -P -O 6500K -b "$BRIGHTNESS"
        done
}

nightlight_pane() {
  load_state
  yad --plug="$KEY" --tabnum=2 \
      --scale --min-value=25 --max-value=65 --value="$T_VAL" \
      --print-partial --title="Night Light (K x100)" --text="Night Light (K x100)" \
      --width=300 --height=50 \
      | while read -r T; do
          load_state
          T_VAL="$T"
          save_state
          TEMP=$((T_VAL * 100))
          redshift -P -O "${TEMP}K"
        done
}

brightness_pane &
P1=$!
nightlight_pane &
P2=$!

yad --paned --key="$KEY" --title="Brightness + Night Light" \
    --width=300 --height=120 --undecorated --fixed --close-on-unfocus --no-buttons
STATUS=$?

kill $P1 $P2 2>/dev/null

# 252 is the common exit code when the window is closed.
if [ "$STATUS" -ne 0 ] && [ "$STATUS" -ne 252 ]; then
  load_state
  yad --scale --min-value=1 --max-value=10 --value=8 \
      --print-partial --title="Brightness" --text="Brightness" --close-on-unfocus \
      --width=300 --height=50 --undecorated --fixed \
      --button="Night Light:sh -c '~/.local/bin/redshift-nightlight.sh &'" \
      | while read -r B; do
          load_state
          B_VAL="$B"
          save_state
          BRIGHTNESS=$(echo "scale=2; $B_VAL/10" | bc -l)
          redshift -P -O 6500K -b "$BRIGHTNESS"
        done
fi
EOF

cat << 'EOF' > ~/.local/bin/redshift-nightlight.sh
#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 namar0x0309
STATE_DIR="$HOME/.local/share/redshift-slider"
STATE_FILE="$STATE_DIR/state"
mkdir -p "$STATE_DIR"
if [ ! -f "$STATE_FILE" ]; then
  {
    echo "B_VAL=8"
    echo "T_VAL=45"
  } > "$STATE_FILE"
fi

load_state() {
  B_VAL=8
  T_VAL=45
  # shellcheck disable=SC1090
  . "$STATE_FILE" 2>/dev/null
}

save_state() {
  {
    echo "B_VAL=$B_VAL"
    echo "T_VAL=$T_VAL"
  } > "$STATE_FILE"
}

load_state
yad --scale --min-value=25 --max-value=65 --value=45 \
    --print-partial --title="Night Light (K x100)" --text="Night Light (K x100)" --close-on-unfocus \
    --width=300 --height=50 --undecorated --fixed \
    | while read -r T; do
        load_state
        T_VAL="$T"
        save_state
        TEMP=$((T_VAL * 100))
        redshift -P -O "${TEMP}K"
      done
EOF

# 3. Make the script executable
chmod +x ~/.local/bin/redshift-slider.sh
chmod +x ~/.local/bin/redshift-nightlight.sh

# 4. Create the Desktop Entry (The "App" icon)
mkdir -p ~/.local/share/applications
cat << EOF > ~/.local/share/applications/redshift-slider.desktop
[Desktop Entry]
Name=Brightness + Night Light
Comment=Adjust brightness and night light using Redshift and YAD
Exec=$HOME/.local/bin/redshift-slider.sh
Icon=display-brightness-symbolic
Terminal=false
Type=Application
Categories=Settings;HardwareSettings;
EOF

echo "Installation complete! You can now find 'Brightness + Night Light' in your menu."

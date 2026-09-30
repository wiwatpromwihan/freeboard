#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PORT=${1:?ระบุพอร์ต USB เช่น ./flash.sh /dev/cu.usbserial-10}
PYTHON=${PYTHON:-python3}
RUNTIME=${IOT_RUNTIME:-"$HOME/.local/share/iot-224"}
[ -f secrets.yaml ] || { echo 'คัดลอก secrets.example.yaml เป็น secrets.yaml และกรอก Wi-Fi ก่อน'; exit 1; }
# Paths containing ':' cannot hold modern Python venvs; build outside the class folder.
mkdir -p "$RUNTIME/firmware"
if [ ! -x "$RUNTIME/venv/bin/esphome" ]; then
  "$PYTHON" -m venv "$RUNTIME/venv"
  "$RUNTIME/venv/bin/pip" install -r requirements.txt
fi
cp project-final.yaml "$RUNTIME/firmware/"
install -m 600 secrets.yaml "$RUNTIME/firmware/secrets.yaml"
cd "$RUNTIME/firmware"
"$RUNTIME/venv/bin/esphome" config project-final.yaml >/dev/null
"$RUNTIME/venv/bin/esphome" compile project-final.yaml
"$RUNTIME/venv/bin/esphome" upload project-final.yaml --device "$PORT"
echo 'เปิด log ด้วย:'
printf '%q logs %q --device %q\n' "$RUNTIME/venv/bin/esphome" "$RUNTIME/firmware/project-final.yaml" "$PORT"

#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# AP37 // RETRO SCI-FI TERMINAL UI (dialog/whiptail)
# Adds:
#  - Theme switching (GREEN/CYAN/AMBER)
#  - Audio (bell + optional system sound + optional termux vibration)
#  - Full-screen boot art (slow pause screen)
#  - KGB floppy loading sequence
#  - EXTRA: CRT SIGNAL INTERFERENCE animation ("glitch storm")
# ============================================================

# ---------- Detect UI tool ----------
UI=""
if command -v dialog >/dev/null 2>&1; then
  UI="dialog"
elif command -v whiptail >/dev/null 2>&1; then
  UI="whiptail"
else
  echo "Need 'dialog' or 'whiptail'."
  echo "Debian/Ubuntu/Kali: sudo apt-get install -y dialog"
  echo "Arch:              sudo pacman -S dialog"
  echo "Fedora:            sudo dnf install -y dialog"
  echo "Termux:            pkg install dialog"
  exit 1
fi

# ---------- Temp / cleanup ----------
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ---------- Config ----------
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ap37"
CFG_FILE="$CFG_DIR/ap37.conf"
mkdir -p "$CFG_DIR"

# Defaults
THEME="${THEME:-CYAN}"     # GREEN | CYAN | AMBER
AUDIO="${AUDIO:-ON}"       # ON | OFF
SFX="${SFX:-OFF}"          # OFF | ON  (tries to play a sound file if found)
VIBE="${VIBE:-OFF}"        # OFF | ON  (termux-vibrate if available)
GLITCH="${GLITCH:-ON}"     # ON | OFF  (interference animation available)

load_cfg() {
  if [[ -f "$CFG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CFG_FILE" || true
  fi
}
save_cfg() {
  cat >"$CFG_FILE" <<EOF
THEME="$THEME"
AUDIO="$AUDIO"
SFX="$SFX"
VIBE="$VIBE"
GLITCH="$GLITCH"
EOF
}

load_cfg

# ---------- Terminal / ncurses behavior ----------
export NCURSES_NO_UTF8_ACS=1

# ---------- Theme ANSI ----------
set_theme() {
  case "$THEME" in
    GREEN)
      C_MAIN=$'\e[32m'   # green
      C_ACC=$'\e[92m'    # bright green
      C_DIM=$'\e[2;32m'
      C_WARN=$'\e[31m'
      C_CYAN=$'\e[36m'
      ;;
    AMBER)
      C_MAIN=$'\e[33m'   # amber/yellow
      C_ACC=$'\e[93m'    # bright amber
      C_DIM=$'\e[2;33m'
      C_WARN=$'\e[31m'
      C_CYAN=$'\e[36m'
      ;;
    CYAN|*)
      C_MAIN=$'\e[36m'   # cyan
      C_ACC=$'\e[96m'    # bright cyan
      C_DIM=$'\e[2;36m'
      C_WARN=$'\e[31m'
      C_CYAN=$'\e[36m'
      ;;
  esac
  C_RESET=$'\e[0m'
  C_WHITE=$'\e[97m'
  C_GRAY=$'\e[90m'
}
set_theme

# ---------- Audio ----------
bell() {
  [[ "$AUDIO" == "ON" ]] || return 0
  printf '\a' >/dev/tty 2>/dev/null || true
}

termux_vibrate() {
  [[ "$VIBE" == "ON" ]] || return 0
  command -v termux-vibrate >/dev/null 2>&1 || return 0
  termux-vibrate -d 30 >/dev/null 2>&1 || true
}

play_sfx() {
  [[ "$SFX" == "ON" ]] || return 0
  [[ "$AUDIO" == "ON" ]] || return 0

  # You can drop a file here to get a real "beep" / "tape click"
  # Supported by many setups if paplay/aplay exists:
  #   ~/.config/ap37/sfx.wav
  local f="$CFG_DIR/sfx.wav"
  [[ -f "$f" ]] || return 0

  if command -v paplay >/dev/null 2>&1; then
    paplay "$f" >/dev/null 2>&1 || true
  elif command -v aplay >/dev/null 2>&1; then
    aplay -q "$f" >/dev/null 2>&1 || true
  fi
}

sfx_tick() { bell; termux_vibrate; }
sfx_heavy() { bell; bell; termux_vibrate; play_sfx; }

# ---------- Timing helpers ----------
sleep_ms() { awk -v m="$1" 'BEGIN{ printf "%.3f", m/1000 }' | xargs sleep; }
sleep_jitter() {
  local base="$1" spread="$2"
  local r=$((RANDOM % (spread + 1)))
  sleep_ms $((base + r))
}

# ---------- UI wrappers ----------
ui_msgbox() {
  local title="$1" text="$2" h="${3:-20}" w="${4:-74}"
  if [[ "$UI" == "dialog" ]]; then
    dialog --clear --no-collapse --colors --title "$title" --msgbox "$text" "$h" "$w"
  else
    whiptail --title "$title" --msgbox "$text" "$h" "$w"
  fi
}

ui_infobox() {
  local title="$1" text="$2" h="${3:-8}" w="${4:-74}"
  if [[ "$UI" == "dialog" ]]; then
    dialog --clear --no-collapse --colors --title "$title" --infobox "$text" "$h" "$w"
  else
    whiptail --title "$title" --msgbox "$text" "$h" "$w"
  fi
}

ui_yesno() {
  local title="$1" text="$2" h="${3:-14}" w="${4:-74}"
  if [[ "$UI" == "dialog" ]]; then
    dialog --clear --no-collapse --colors --title "$title" --yesno "$text" "$h" "$w"
  else
    whiptail --title "$title" --yesno "$text" "$h" "$w"
  fi
}

ui_menu() {
  local title="$1" text="$2"
  shift 2
  local h="${1:-18}" w="${2:-74}" mh="${3:-10}"
  shift 3

  local out="$TMP_DIR/menu.out"
  if [[ "$UI" == "dialog" ]]; then
    dialog --clear --no-collapse --colors --title "$title" \
      --menu "$text" "$h" "$w" "$mh" "$@" 2>"$out" || return 1
  else
    whiptail --title "$title" \
      --menu "$text" "$h" "$w" "$mh" "$@" 2>"$out" || return 1
  fi
  cat "$out"
}

ui_gauge() {
  local title="$1" text="$2" steps="$3"
  if [[ "$UI" == "dialog" ]]; then
    {
      for ((i=0;i<=100;i+=steps)); do
        echo "$i"
        echo "XXX"
        echo "$text"
        echo "[$(printf "%3d" "$i")%]  BUS: STABLE | CRC: OK | NOISE: LOW"
        echo "XXX"
        sleep_jitter 35 55
      done
    } | dialog --clear --colors --title "$title" --gauge "$text" 12 78 0
  else
    {
      for ((i=0;i<=100;i+=steps)); do
        echo "$i"
        sleep_jitter 35 55
      done
    } | whiptail --title "$title" --gauge "$text" 12 78 0
  fi
}

# Full-screen "pause" style boot art (dialog only). For whiptail, it falls back to msgbox.
ui_fullscreen_art() {
  local title="$1" art="$2" seconds="$3"
  if [[ "$UI" == "dialog" ]]; then
    # --pause draws a centered timer; use it like a "loading screen"
    dialog --clear --no-collapse --colors --title "$title" --pause "$art" 0 0 "$seconds"
  else
    ui_msgbox "$title" "$art" 24 90
    sleep "$seconds" || true
  fi
}

# ---------- ASCII / Content ----------
BOOT_BANNER=$'\
  █████╗ ██████╗ ██████╗ ███████╗\n\
 ██╔══██╗██╔══██╗██╔══██╗██╔════╝\n\
 ███████║██████╔╝██████╔╝█████╗  \n\
 ██╔══██║██╔═══╝ ██╔═══╝ ██╔══╝  \n\
 ██║  ██║██║     ██║     ███████╗\n\
 ╚═╝  ╚═╝╚═╝     ╚═╝     ╚══════╝\n\
      AP37 // GCI TERMINAL  (retro build 0x1984)'

MARINE_ASCII=$'\
           ___________________________________________________\n\
          /                                                   /|\n\
         /   [AP37] FIELD OPERATOR:  A-7 "PALADIN"           / |\n\
        /___________________________________________________/  |\n\
        |                                                   |  |\n\
        |            .-\"\"\"\"\"\"\"-._                          |  |\n\
        |          .'  _   _     '.                         |  |\n\
        |         /   (o) (o)      \\                        |  |\n\
        |        |      .-\"-.       |   HELMET STATUS: OK    |  |\n\
        |        |     /  _  \\      |   HUD: GREENLINE       |  |\n\
        |         \\    \\ (_) /     /    COMMS: ENCRYPTED     |  |\n\
        |          '._  '---'  _.'                          |  |\n\
        |             '-.___.-'                             |  |\n\
        |               /|\\                                 |  |\n\
        |              /_|_\\   PLATE: MK-IV                  |  |\n\
        |              || ||   O2: 78%  TEMP: 36.9C         |  |\n\
        |             _|| ||_  RADIATION: LOW               |  |\n\
        |            /__| |__\\                             |  |\n\
        |                                                   |  /\n\
        |___________________________________________________| / \n\
        |___________________________________________________|/'

SKELETON_ASCII=$'\
   ╔════════════════════════════════════════════════════════════╗\n\
   ║  BIOS/SCAN: \"SKELETAL TELEMETRY\"  :: MODE = X-RAY         ║\n\
   ╠════════════════════════════════════════════════════════════╣\n\
   ║                        .-\"\"\"-.                             ║\n\
   ║                       /  .-.  \\                            ║\n\
   ║                      |  /   \\  |                           ║\n\
   ║                      |  \\___/  |                           ║\n\
   ║                       \\  `-`  /                            ║\n\
   ║                        `-._.-`                             ║\n\
   ║                           |                                ║\n\
   ║                       .---+---.                            ║\n\
   ║                      /   /|\\   \\                           ║\n\
   ║                     /   /_|_\\   \\                          ║\n\
   ║                        /_|_\\                               ║\n\
   ║                        / | \\                               ║\n\
   ║                       /  |  \\                              ║\n\
   ║                      /   |   \\                             ║\n\
   ║                     /   / \\   \\                            ║\n\
   ║                    /___/   \\___\\                           ║\n\
   ║  ANOMALY FLAGS: [ ] cranial  [ ] spine  [!] left ulna      ║\n\
   ║  NOTE: micro-fracture healed / cyber-splint present         ║\n\
   ╚════════════════════════════════════════════════════════════╝'

KGB_FLOPPY_ART=$'\
╔══════════════════════════════════════════════════════════════════════╗\n\
║  'KGB ARCHIVE LOADER'  ::  FLOPPY BUS / MAGNETIC TAPE EMULATION      ║\n\
╠══════════════════════════════════════════════════════════════════════╣\n\
║   ┌───────────────┐          ┌──────────────────────────────────┐   ║\n\
║   │   _________   │          │  READ: SECTOR 00A9  |  MODE: R/W  │   ║\n\
║   │  /  ___   /|  │          │  AUTH:  RED-STAMP   |  CRC: OK    │   ║\n\
║   │ /__/__/__/ |  │          │  DECLASS: NO        |  NOISE: LOW │   ║\n\
║   │ |  ____  | |  │          └──────────────────────────────────┘   ║\n\
║   │ | |____| | |  │                                                   ║\n\
║   │ |________|/   │   *drive head*   *click*   *whirr*                ║\n\
║   └───────────────┘                                                   ║\n\
║  NOTE: do not power-cycle during decrypt.                              ║\n\
╚══════════════════════════════════════════════════════════════════════╝'

TERMINAL_LOG=$'\
[BOOT] ROMCHECK...........OK\n\
[BOOT] DMA MAP............OK\n\
[BOOT] CRT SYNC...........LOCK\n\
[BOOT] VOX BUS............STABLE\n\
[BOOT] TAPE SECTOR........CLEAN\n\
[BOOT] WATCHDOG...........ARMED\n\
[SYS ] AP37 CORE..........ONLINE\n\
[SYS ] AUTH MODULE........SEALED\n\
[SYS ] OPERATOR LINK......PENDING\n\
\n\
>> establishing operator telemetry...\n\
>> loading mission partitions...\n\
>> hashing keyspace...............done\n\
>> decrypting HUD buffers.........done\n\
\n\
STATUS: GREENLINE // \"WE DO NOT DREAM. WE EXECUTE.\"'

# ---------- Glitch / interference feature ----------
rand_glyph() {
  local glyphs='@#$%&*+=-:;,.?/|\_~^'
  local idx=$((RANDOM % ${#glyphs}))
  printf "%s" "${glyphs:idx:1}"
}

corrupt_line() {
  # Corrupt ~10% of characters
  local s="$1"
  local out=""
  local i
  for ((i=0;i<${#s};i++)); do
    if (( RANDOM % 10 == 0 )); then
      out+=$(rand_glyph)
    else
      out+="${s:i:1}"
    fi
  done
  printf "%s" "$out"
}

signal_interference() {
  [[ "$GLITCH" == "ON" ]] || return 0

  local base=$'\
[LINK] carrier.............LOCK\n\
[LINK] phase...............SYNC\n\
[LINK] ghost signal........NONE\n\
[LINK] noise floor.........LOW\n\
[LINK] handshake...........OK\n\
'
  local i
  for ((i=0;i<24;i++)); do
    sfx_tick
    local a b c d e
    a="$(corrupt_line "[LINK] carrier.............LOCK")"
    b="$(corrupt_line "[LINK] phase...............SYNC")"
    c="$(corrupt_line "[LINK] ghost signal........NONE")"
    d="$(corrupt_line "[LINK] noise floor.........LOW")"
    e="$(corrupt_line "[LINK] handshake...........OK")"
    ui_infobox "AP37 // SIGNAL INTERFERENCE" "\
${C_WARN}WARNING${C_RESET}: transient EMI detected\n\n\
${C_MAIN}${a}\n${b}\n${c}\n${d}\n${e}${C_RESET}\n\n\
${C_DIM}>> shielding... rerouting ground... stabilizing...${C_RESET}" 16 78
    sleep_jitter 60 80
  done
  sfx_heavy
  ui_infobox "AP37 // SIGNAL INTERFERENCE" "\
${C_MAIN}SIGNAL${C_RESET}: stabilized\n${C_DIM}noise floor returned to baseline${C_RESET}" 8 78
  sleep_ms 550
}

# ---------- Pages ----------
page_boot() {
  clear || true

  # Fullscreen thematic art
  local art
  art="\
${C_ACC}${BOOT_BANNER}${C_RESET}\n\n\
${C_WHITE}PORTAL-STYLE END CREDITS HUM.${C_RESET}  ${C_DIM}(simulated)${C_RESET}\n\
${C_DIM}scanlines: ON  bloom: implied  phosphor: nostalgic${C_RESET}\n\n\
${C_MAIN}>>${C_RESET} ${C_WHITE}WAKE SEQUENCE${C_RESET}  |  ${C_MAIN}AP37${C_RESET}  |  ${C_WHITE}GCI BUS${C_RESET}\n\
${C_MAIN}>>${C_RESET} ${C_DIM}do not blink. do not move. do not trust silence.${C_RESET}\n\n\
${C_DIM}pressing power into old metal...${C_RESET}\n\
${C_DIM}listening to fans like prayers...${C_RESET}"
  ui_fullscreen_art "AP37 // COLD START" "$art" 3
  sfx_heavy

  # POST
  ui_gauge "AP37 // POST" "Power-On Self-Test (1984 mode)\n\n• CRT coil\n• bus arbitration\n• memory weave\n• telemetry link" 6
  sfx_tick

  # KGB floppy loader (slow pause screen vibe)
  ui_fullscreen_art "AP37 // KGB ARCHIVE LOADER" "${C_MAIN}${KGB_FLOPPY_ART}${C_RESET}\n\n${C_DIM}loading: classified module blocks from floppy bus...${C_RESET}\n${C_DIM}head: SEEK  /  sector map: crawling  /  checksum: cold${C_RESET}" 5

  # Interference storm (extra feature)
  signal_interference

  ui_msgbox "AP37 // HANDSHAKE" "\
${C_MAIN}LINK${C_RESET}: secure channel established\n\
${C_ACC}CRC${C_RESET} : 0x00\n\
${C_DIM}NOTE${C_RESET}: scanlines simulated; reality not guaranteed\n\n\
Press ENTER to enter the terminal." 13 78
}

page_terminal() {
  ui_msgbox "AP37 // TERMINAL" "\
${C_MAIN}AP37${C_RESET} terminal stream (read-only)\n\n${C_WHITE}${TERMINAL_LOG}${C_RESET}\n\n\
Tip: Use the menu to open Operator Profile and X-RAY." 22 86
}

page_operator_profile() {
  ui_msgbox "AP37 // OPERATOR PROFILE" "\
${C_MAIN}OPERATOR${C_RESET}: A-7 \"PALADIN\"\n\
${C_MAIN}RANK${C_RESET}    : FIELD MARINE\n\
${C_MAIN}LOADOUT${C_RESET} : rifle / shield / medkit\n\
${C_MAIN}VIBE${C_RESET}    : CRT noir / steel hymn\n\n${C_WHITE}${MARINE_ASCII}${C_RESET}" 24 92
}

page_skeletal_scan() {
  ui_msgbox "AP37 // X-RAY" "\
${C_MAIN}SCAN${C_RESET}: skeletal overlay\n\
${C_WARN}WARNING${C_RESET}: retro imaging artifacts present\n\n${C_WHITE}${SKELETON_ASCII}${C_RESET}" 24 92
}

page_glitch_showcase() {
  ui_msgbox "AP37 // INTERFERENCE DEMO" "\
This runs the extra \"signal storm\" sequence.\n\
It looks like corrupted telemetry, then snaps back.\n\n\
Proceed?" 12 74
  signal_interference
  ui_msgbox "AP37 // INTERFERENCE DEMO" "${C_MAIN}OK${C_RESET}: baseline restored." 7 60
}

page_settings() {
  while true; do
    local theme_label audio_label sfx_label vibe_label glitch_label
    theme_label="Theme: ${THEME}"
    audio_label="Audio: ${AUDIO} (terminal bell)"
    sfx_label="SFX: ${SFX} (plays $CFG_DIR/sfx.wav if exists)"
    vibe_label="Vibrate: ${VIBE} (termux-vibrate)"
    glitch_label="Interference feature: ${GLITCH}"

    local choice
    choice="$(ui_menu "AP37 // SETTINGS" "\
${C_DIM}These settings persist in:${C_RESET} ${C_WHITE}$CFG_FILE${C_RESET}\n\nSelect:" \
      20 86 10 \
      "1" "$theme_label" \
      "2" "$audio_label" \
      "3" "$sfx_label" \
      "4" "$vibe_label" \
      "5" "$glitch_label" \
      "6" "Save settings" \
      "0" "Back" \
    )" || return 0

    case "$choice" in
      1)
        local t
        t="$(ui_menu "AP37 // THEME" "Pick a display theme:" 14 60 6 \
            "GREEN" "Greenline BIOS" \
            "CYAN"  "GCI Cyan Terminal" \
            "AMBER" "Old-iron Amber" \
        )" || true
        if [[ -n "${t:-}" ]]; then
          THEME="$t"; set_theme; sfx_tick
        fi
        ;;
      2)
        if [[ "$AUDIO" == "ON" ]]; then AUDIO="OFF"; else AUDIO="ON"; fi
        sfx_tick
        ;;
      3)
        if [[ "$SFX" == "ON" ]]; then SFX="OFF"; else SFX="ON"; fi
        sfx_tick
        ;;
      4)
        if [[ "$VIBE" == "ON" ]]; then VIBE="OFF"; else VIBE="ON"; fi
        sfx_tick
        ;;
      5)
        if [[ "$GLITCH" == "ON" ]]; then GLITCH="OFF"; else GLITCH="ON"; fi
        sfx_tick
        ;;
      6)
        save_cfg
        ui_msgbox "AP37 // SETTINGS" "${C_MAIN}SAVED${C_RESET} to:\n${C_WHITE}$CFG_FILE${C_RESET}" 8 78
        ;;
      0) break ;;
    esac
  done
}

page_about() {
  ui_msgbox "AP37 // ABOUT" "\
${C_MAIN}AP37${C_RESET} retro terminal.\n\n\
Goals:\n\
• portal end-credits terminal mood\n\
• GCI-cinematic console energy\n\
• 1980s BIOS / CRT punk\n\n\
Tool: ${UI}\n\
Host: $(uname -srm)\n\
Config: $CFG_FILE\n" 18 86
}

main_menu() {
  while true; do
    local choice
    choice="$(ui_menu "AP37 // MAINFRAME" "\
${C_MAIN}OVERRIDE${C_RESET}: operator authorized\n\
${C_ACC}STATUS${C_RESET}: greenline\n\nSelect module:" \
      20 86 10 \
      "1" "Terminal Stream" \
      "2" "Operator Profile (Space Marine)" \
      "3" "Skeletal Telemetry (X-RAY)" \
      "4" "Interference Demo (extra feature)" \
      "5" "Settings (theme/audio)" \
      "6" "About" \
      "0" "Shutdown" \
    )" || return 0

    case "$choice" in
      1) sfx_tick; page_terminal ;;
      2) sfx_tick; page_operator_profile ;;
      3) sfx_tick; page_skeletal_scan ;;
      4) sfx_tick; page_glitch_showcase ;;
      5) sfx_tick; page_settings ;;
      6) sfx_tick; page_about ;;
      0)
        ui_yesno "AP37 // SHUTDOWN" "\
${C_WARN}CONFIRM${C_RESET}: cut power?\n\nThis will exit the terminal." 12 74
        if [[ $? -eq 0 ]]; then
          sfx_heavy
          break
        fi
        ;;
    esac
  done
}

# ---------- Run ----------
clear || true
page_boot
main_menu
clear || true
echo "AP37: power down. (no dreams, only exit codes)"
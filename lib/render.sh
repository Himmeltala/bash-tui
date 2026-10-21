# 显示宽度与画面原语；宽度按终端列计算，非 ASCII 记两列。

_tui_measure() {
  local s=$1 i c
  _TUI_WIDTH=0
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    if [[ "$c" == [[:ascii:]] ]]; then
      _TUI_WIDTH=$((_TUI_WIDTH + 1))
    else
      _TUI_WIDTH=$((_TUI_WIDTH + 2))
    fi
  done
  return 0
}

_tui_clip_to() {
  local s=$1 max=$2 i c inc w=0
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    if [[ "$c" == [[:ascii:]] ]]; then
      inc=1
    else
      inc=2
    fi
    ((w + inc > max)) && break
    w=$((w + inc))
  done
  _TUI_TEXT=${s:0:i}
  return 0
}

tui_title() {
  printf '\n %s▌%s %s%s%s\n' "$_TUI_C_ACCENT" "$_TUI_C_RESET" "$_TUI_C_BOLD" "$1" "$_TUI_C_RESET" >&2
  return 0
}

tui_subtitle() {
  [[ -n "${1:-}" ]] || return 0
  printf '   %s%s%s\n' "$_TUI_C_DIM" "$1" "$_TUI_C_RESET" >&2
  return 0
}

tui_hint() {
  local first=1
  printf ' ' >&2
  while (($# >= 2)); do
    ((first)) || printf '   ' >&2
    printf '%s%s%s %s%s%s' "$_TUI_C_ACCENT" "$1" "$_TUI_C_RESET" "$_TUI_C_DIM" "$2" "$_TUI_C_RESET" >&2
    first=0
    shift 2
  done
  printf '\n' >&2
  return 0
}

tui_rule() {
  local i n=${1:-$((_TUI_COLS - 2))}
  printf ' %s' "$_TUI_C_DIM" >&2
  for ((i = 0; i < n; i++)); do
    printf '─' >&2
  done
  printf '%s\n' "$_TUI_C_RESET" >&2
  return 0
}

tui_row() {
  local cursor=$1 mark=$2 primary=$3 secondary=${4:-}
  local fixed=5 room used
  [[ -n "$mark" ]] && fixed=9
  room=$((_TUI_COLS - fixed - 2))
  _tui_clip_to "$primary" "$room"
  primary=$_TUI_TEXT

  if ((cursor)); then
    printf ' %s▌%s ' "$_TUI_C_ACCENT" "$_TUI_C_RESET" >&2
  else
    printf '   ' >&2
  fi

  if [[ -n "$mark" ]]; then
    if [[ "$mark" == '[x]' ]]; then
      printf '%s%s%s ' "$_TUI_C_OK" "$mark" "$_TUI_C_RESET" >&2
    else
      printf '%s%s%s ' "$_TUI_C_DIM" "$mark" "$_TUI_C_RESET" >&2
    fi
  fi

  if ((cursor)); then
    printf '%s%s%s' "$_TUI_C_BOLD" "$primary" "$_TUI_C_RESET" >&2
  else
    printf '%s' "$primary" >&2
  fi

  if [[ -n "$secondary" ]]; then
    _tui_measure "$primary"
    used=$_TUI_WIDTH
    room=$((_TUI_COLS - fixed - used - 2))
    if ((room > 0)); then
      _tui_clip_to "$secondary" "$room"
      secondary=$_TUI_TEXT
      printf '  %s%s%s' "$_TUI_C_DIM" "$secondary" "$_TUI_C_RESET" >&2
    fi
  fi
  printf '\n' >&2
  return 0
}

tui_status() {
  local left=$1 right=${2:-} pad lw rw
  printf ' %s%s%s' "$_TUI_C_DIM" "$left" "$_TUI_C_RESET" >&2
  if [[ -n "$right" ]]; then
    _tui_measure "$left"
    lw=$_TUI_WIDTH
    _tui_measure "$right"
    rw=$_TUI_WIDTH
    pad=$((_TUI_COLS - 1 - lw - rw))
    ((pad < 1)) && pad=1
    printf '%*s' "$pad" '' >&2
    printf '%s%s%s' "$_TUI_C_DIM" "$right" "$_TUI_C_RESET" >&2
  fi
  printf '\n' >&2
  return 0
}

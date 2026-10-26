# 显示宽度与画面原语；宽度按终端列计算，非 ASCII 记两列。
# 每行先在变量里拼好再一次性写出，避免逐段 printf 触发大量写系统调用。

# 截断结果按「宽度 + 原文」缓存；翻页与移动光标时同一批行会反复重画。
declare -A _TUI_CLIP_TEXT=()
declare -A _TUI_CLIP_WIDTH=()

# 判断字符串是否全为 ASCII；UTF-8 的非 ASCII 字节都落在 0x80 以上。
_tui_detect_ascii() {
  local had=0 old=''
  if [[ -n ${LC_ALL+x} ]]; then
    had=1
    old=$LC_ALL
  fi
  LC_ALL=C
  if [[ $1 == *[$'\x80'-$'\xff']* ]]; then
    _TUI_ASCII=0
  else
    _TUI_ASCII=1
  fi
  if ((had)); then
    LC_ALL=$old
  else
    unset LC_ALL
  fi
  return 0
}

_tui_measure() {
  local s=$1 i c
  _tui_detect_ascii "$s"
  if ((_TUI_ASCII)); then
    _TUI_WIDTH=${#s}
    return 0
  fi

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

# 截断后同时把显示宽度写进 _TUI_WIDTH，调用方不必再量一遍。
_tui_clip_to() {
  local s=$1 max=$2 i c inc w=0 key

  _TUI_WIDTH=0
  _TUI_TEXT=''
  ((max <= 0)) && return 0

  key="${max}"$'\x1f'"${s}"
  if [[ -n ${_TUI_CLIP_TEXT[$key]+x} ]]; then
    _TUI_TEXT=${_TUI_CLIP_TEXT[$key]}
    _TUI_WIDTH=${_TUI_CLIP_WIDTH[$key]}
    return 0
  fi

  _tui_detect_ascii "$s"
  if ((_TUI_ASCII)); then
    if ((${#s} <= max)); then
      _TUI_TEXT=$s
      _TUI_WIDTH=${#s}
    else
      _TUI_TEXT=${s:0:max}
      _TUI_WIDTH=$max
    fi
    _TUI_CLIP_TEXT[$key]=$_TUI_TEXT
    _TUI_CLIP_WIDTH[$key]=$_TUI_WIDTH
    return 0
  fi

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
  _TUI_WIDTH=$w
  _TUI_CLIP_TEXT[$key]=$_TUI_TEXT
  _TUI_CLIP_WIDTH[$key]=$_TUI_WIDTH
  return 0
}

tui_title() {
  local line=''
  printf -v line '\n %s▌%s %s%s%s%s' \
    "$_TUI_C_ACCENT" "$_TUI_C_RESET" "$_TUI_C_BOLD" "$1" "$_TUI_C_RESET" "$_TUI_CLEAR_LINE"
  printf '%s' "$line" >&2
  return 0
}

tui_subtitle() {
  [[ -n "${1:-}" ]] || return 0
  local line=''
  printf -v line '   %s%s%s%s' "$_TUI_C_DIM" "$1" "$_TUI_C_RESET" "$_TUI_CLEAR_LINE"
  printf '%s\n' "$line" >&2
  return 0
}

tui_hint() {
  local first=1 line=' ' part=''
  while (($# >= 2)); do
    ((first)) || line+='   '
    printf -v part '%s%s%s %s%s%s' \
      "$_TUI_C_ACCENT" "$1" "$_TUI_C_RESET" "$_TUI_C_DIM" "$2" "$_TUI_C_RESET"
    line+=$part
    first=0
    shift 2
  done
  line+=$_TUI_CLEAR_LINE
  printf '%s\n' "$line" >&2
  return 0
}

tui_rule() {
  local i n=${1:-$((_TUI_COLS - 2))} pad=''
  printf -v pad '%*s' "$n" ''
  printf ' %s%s%s%s\n' "$_TUI_C_DIM" "${pad// /─}" "$_TUI_C_RESET" "$_TUI_CLEAR_LINE" >&2
  return 0
}

tui_row() {
  local cursor=$1 mark=$2 primary=$3 secondary=${4:-}
  local fixed=5 room used line='' part=''
  [[ -n "$mark" ]] && fixed=9
  room=$((_TUI_COLS - fixed - 2))
  _tui_clip_to "$primary" "$room"
  primary=$_TUI_TEXT

  if ((cursor)); then
    printf -v part ' %s▌%s ' "$_TUI_C_ACCENT" "$_TUI_C_RESET"
  else
    printf -v part '   '
  fi
  line+=$part

  if [[ -n "$mark" ]]; then
    if [[ "$mark" == '[x]' ]]; then
      printf -v part '%s%s%s ' "$_TUI_C_OK" "$mark" "$_TUI_C_RESET"
    else
      printf -v part '%s%s%s ' "$_TUI_C_DIM" "$mark" "$_TUI_C_RESET"
    fi
    line+=$part
  fi

  if ((cursor)); then
    printf -v part '%s%s%s' "$_TUI_C_BOLD" "$primary" "$_TUI_C_RESET"
  else
    printf -v part '%s' "$primary"
  fi
  line+=$part

  if [[ -n "$secondary" ]]; then
    used=$_TUI_WIDTH
    room=$((_TUI_COLS - fixed - used - 2))
    if ((room > 0)); then
      _tui_clip_to "$secondary" "$room"
      printf -v part '  %s%s%s' "$_TUI_C_DIM" "$_TUI_TEXT" "$_TUI_C_RESET"
      line+=$part
    fi
  fi
  line+=$_TUI_CLEAR_LINE
  printf '%s\n' "$line" >&2
  return 0
}

tui_status() {
  local left=$1 right=${2:-} pad lw rw spaces='' line=''
  printf -v line ' %s%s%s' "$_TUI_C_DIM" "$left" "$_TUI_C_RESET"
  if [[ -n "$right" ]]; then
    _tui_measure "$left"
    lw=$_TUI_WIDTH
    _tui_measure "$right"
    rw=$_TUI_WIDTH
    pad=$((_TUI_COLS - 1 - lw - rw))
    ((pad < 1)) && pad=1
    printf -v spaces '%*s' "$pad" ''
    line+=$spaces
    printf -v line '%s%s%s%s%s' "$line" "$_TUI_C_DIM" "$right" "$_TUI_C_RESET" "$_TUI_CLEAR_LINE"
  else
    line+=$_TUI_CLEAR_LINE
  fi
  printf '%s\n' "$line" >&2
  return 0
}

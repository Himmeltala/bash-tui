# 终端生命周期、主题、尺寸与错误码；内部状态一律 _TUI_ 前缀。

readonly TUI_OK=0
readonly TUI_CANCEL=1
readonly TUI_EMPTY=2
readonly TUI_ERROR=3
readonly TUI_BACK=4

: "${TUI_PRESELECT:=}"
: "${TUI_LABEL_ALL:=全部}"
: "${TUI_LABEL_ALL_DESC:=选中全部模块}"
: "${TUI_MIN_COLS:=40}"
: "${TUI_ESC_TIMEOUT:=0.05}"

readonly _TUI_CHROME_LINES=8
readonly _TUI_DEFAULT_LINES=24
readonly _TUI_DEFAULT_COLS=100
readonly _TUI_ENTER_SCREEN=$'\033[?1049h\033[?25l'
readonly _TUI_LEAVE_SCREEN=$'\033[?1049l\033[?25h'
readonly _TUI_SHOW_CURSOR=$'\033[?25h'
readonly _TUI_HIDE_CURSOR=$'\033[?25l'
readonly _TUI_CLEAR_SCREEN=$'\033[H'
readonly _TUI_CLEAR_LINE=$'\033[K'
readonly _TUI_CLEAR_BELOW=$'\033[J'
readonly _TUI_SYNC_ON=$'\033[?2026h'
readonly _TUI_SYNC_OFF=$'\033[?2026l'

_TUI_LINES=$_TUI_DEFAULT_LINES
_TUI_COLS=$_TUI_DEFAULT_COLS
_TUI_C_RESET=''
_TUI_C_ACCENT=''
_TUI_C_DIM=''
_TUI_C_OK=''
_TUI_C_WARN=''
_TUI_C_BOLD=''
_TUI_WIDTH=0
_TUI_TEXT=''
_TUI_KEY=''
_TUI_ACTIVE=0
_TUI_DEPTH=0
_TUI_CURSOR=0
_TUI_OFFSET=0
_TUI_SIZE_DIRTY=1
_TUI_SIZE_VALID=0
_TUI_PAGE_ALIGN=0
_TUI_TRAP_EXIT=''
_TUI_TRAP_INT=''
_TUI_TRAP_TERM=''
_TUI_TRAP_WINCH=''

_tui_error() { printf 'bash-tui: %s\n' "$*" >&2; }

# 只在加载时调用一次，界面运行中不要重置，否则会清掉当前状态。
_tui_reset_state() {
  _TUI_LINES=$_TUI_DEFAULT_LINES
  _TUI_COLS=$_TUI_DEFAULT_COLS
  _TUI_C_RESET=''
  _TUI_C_ACCENT=''
  _TUI_C_DIM=''
  _TUI_C_OK=''
  _TUI_C_WARN=''
  _TUI_C_BOLD=''
  _TUI_WIDTH=0
  _TUI_TEXT=''
  _TUI_KEY=''
  _TUI_ACTIVE=0
  _TUI_DEPTH=0
  _TUI_CURSOR=0
  _TUI_OFFSET=0
  _TUI_SIZE_DIRTY=1
  _TUI_SIZE_VALID=0
  _TUI_PAGE_ALIGN=0
  _TUI_TRAP_EXIT=''
  _TUI_TRAP_INT=''
  _TUI_TRAP_TERM=''
  _TUI_TRAP_WINCH=''
  return 0
}

tui_theme() {
  _TUI_C_RESET=''
  _TUI_C_ACCENT=''
  _TUI_C_DIM=''
  _TUI_C_OK=''
  _TUI_C_WARN=''
  _TUI_C_BOLD=''
  if [[ -n ${NO_COLOR:-} || ${TERM:-} == dumb ]]; then
    return 0
  fi
  _TUI_C_RESET=$'\033[0m'
  _TUI_C_ACCENT=$'\033[1;38;5;45m'
  _TUI_C_DIM=$'\033[38;5;244m'
  _TUI_C_OK=$'\033[38;5;42m'
  _TUI_C_WARN=$'\033[38;5;214m'
  _TUI_C_BOLD=$'\033[1m'
  return 0
}

# 尺寸只在启动与收到 WINCH 后查询；每帧都起两个 tput 进程会让按键明显变慢。
tui_size() {
  local lines=''
  local cols=''

  if ((_TUI_SIZE_VALID && !_TUI_SIZE_DIRTY)); then
    return 0
  fi

  if command -v tput >/dev/null 2>&1; then
    lines=$(tput lines 2>/dev/null) || lines=''
    cols=$(tput cols 2>/dev/null) || cols=''
  else
    lines=${LINES:-}
    cols=${COLUMNS:-}
  fi

  [[ $lines =~ ^[0-9]+$ ]] && ((lines > 0)) || lines=$_TUI_DEFAULT_LINES
  [[ $cols =~ ^[0-9]+$ ]] && ((cols > 0)) || cols=$_TUI_DEFAULT_COLS
  ((cols < TUI_MIN_COLS)) && cols=$TUI_MIN_COLS
  _TUI_LINES=$lines
  _TUI_COLS=$cols
  _TUI_SIZE_VALID=1
  _TUI_SIZE_DIRTY=0
  return 0
}

_tui_mark_resize() {
  _TUI_SIZE_DIRTY=1
  return 0
}

_tui_restore_trap() {
  local definition=$1
  local signal=$2
  if [[ -n "$definition" ]]; then
    eval "$definition"
  else
    trap - "$signal"
  fi
  return 0
}

_tui_trap_push() {
  _TUI_TRAP_EXIT=$(trap -p EXIT)
  _TUI_TRAP_INT=$(trap -p INT)
  _TUI_TRAP_TERM=$(trap -p TERM)
  _TUI_TRAP_WINCH=$(trap -p WINCH)
  trap '_tui_on_signal 130' INT
  trap '_tui_on_signal 130' TERM
  trap '_tui_mark_resize' WINCH
  trap '_tui_leave_screen' EXIT
  return 0
}

_tui_trap_pop() {
  _tui_restore_trap "${_TUI_TRAP_EXIT:-}" EXIT
  _tui_restore_trap "${_TUI_TRAP_INT:-}" INT
  _tui_restore_trap "${_TUI_TRAP_TERM:-}" TERM
  _tui_restore_trap "${_TUI_TRAP_WINCH:-}" WINCH
  _TUI_TRAP_EXIT=''
  _TUI_TRAP_INT=''
  _TUI_TRAP_TERM=''
  _TUI_TRAP_WINCH=''
  return 0
}

_tui_on_signal() {
  _TUI_DEPTH=1
  _tui_leave_screen
  exit "$1"
}

_tui_leave_screen() {
  if ((_TUI_ACTIVE == 1)); then
    printf '%s%s' "$_TUI_SYNC_OFF" "$_TUI_LEAVE_SCREEN" >&2
    _TUI_ACTIVE=0
  fi
  _tui_trap_pop
  return 0
}

tui_begin() {
  _TUI_DEPTH=$((_TUI_DEPTH + 1))
  if ((_TUI_DEPTH > 1)); then
    return 0
  fi
  tui_theme
  _TUI_SIZE_DIRTY=1
  tui_size
  _tui_trap_push
  printf '%s' "$_TUI_ENTER_SCREEN" >&2
  _TUI_ACTIVE=1
  return 0
}

tui_end() {
  if ((_TUI_DEPTH == 0)); then
    return 0
  fi
  _TUI_DEPTH=$((_TUI_DEPTH - 1))
  if ((_TUI_DEPTH > 0)); then
    return 0
  fi
  _tui_leave_screen
  return 0
}

# 只回光标到左上角，不清整屏；每行画完用 EL 清掉本行尾部，帧尾再清光标下方。
tui_clear() {
  printf '%s' "$_TUI_CLEAR_SCREEN" >&2
  return 0
}

# 支持 DEC 2026 的终端会把一帧当成整体提交，避免逐行重绘时闪。
tui_frame_begin() {
  printf '%s' "$_TUI_SYNC_ON" >&2
  return 0
}

tui_frame_end() {
  printf '%s%s' "$_TUI_CLEAR_BELOW" "$_TUI_SYNC_OFF" >&2
  return 0
}

_tui_reset_state

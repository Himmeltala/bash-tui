# 单行输入、确认与原地等待按键；结果只走 stdout。

tui_input() {
  if (($# < 2)); then
    _tui_error 'tui_input 需要标题与提示'
    return "$TUI_ERROR"
  fi
  local title=$1 prompt=$2 default=${3:-}
  local answer=''
  local rc=$TUI_OK

  tui_begin
  tui_size
  tui_frame_begin
  tui_clear
  tui_title "$title"
  tui_subtitle "$prompt"
  tui_hint '回车' '确认' 'Ctrl+C' '取消'
  tui_rule
  tui_frame_end
  printf '%s' "$_TUI_SHOW_CURSOR" >&2
  IFS= read -re -i "$default" -p ' > ' answer || rc=$TUI_CANCEL
  printf '%s' "$_TUI_HIDE_CURSOR" >&2
  tui_end

  ((rc == TUI_OK)) || return "$rc"
  printf '%s\n' "$answer"
  return "$TUI_OK"
}

tui_confirm() {
  if (($# < 2)); then
    _tui_error 'tui_confirm 需要标题与提示'
    return "$TUI_ERROR"
  fi
  local title=$1 prompt=$2
  local key=''

  tui_begin
  tui_size
  tui_frame_begin
  tui_clear
  tui_title "$title"
  tui_subtitle "$prompt"
  tui_hint 'y' '确认' 'n' '取消'
  tui_rule
  tui_frame_end
  IFS= read -rsn1 key || key=''
  tui_end

  [[ "$key" == y || "$key" == Y ]]
  return $?
}

tui_wait_key() {
  local prompt=${1:-}
  printf '%s ' "$prompt" >&2
  if ! _tui_read_key; then
    printf '\n' >&2
    return "$TUI_CANCEL"
  fi
  printf '\n' >&2
  printf '%s\n' "$_TUI_KEY"
  return "$TUI_OK"
}

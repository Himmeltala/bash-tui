# 分页查看文本文件；q、回车或 ESC 关闭，↑↓ 与 j k 滚动，空格翻页。

tui_textbox() {
  if (($# < 2)); then
    _tui_error 'tui_textbox 需要标题与文件路径'
    return "$TUI_ERROR"
  fi
  local title=$1 file=$2
  if [[ ! -f "$file" || ! -r "$file" ]]; then
    _tui_error "tui_textbox 读不到文件: $file"
    return "$TUI_ERROR"
  fi

  local -a lines=()
  if ! mapfile -t lines < "$file"; then
    _tui_error "tui_textbox 读取失败: $file"
    return "$TUI_ERROR"
  fi
  local n=${#lines[@]}
  local cursor=0
  local offset=0
  local listh=0
  local row=0

  tui_begin
  while :; do
    tui_size
    listh=$((_TUI_LINES - _TUI_CHROME_LINES))
    ((listh > n)) && listh=$n
    ((listh < 1)) && listh=1
    _tui_clamp_window "$cursor" "$offset" "$listh" "$n"
    cursor=$_TUI_CURSOR
    offset=$_TUI_OFFSET

    tui_clear
    tui_title "$title"
    tui_hint '↑↓' '滚动' '空格' '翻页' 'q' '关闭'
    tui_rule
    for ((row = offset; row < offset + listh && row < n; row++)); do
      _tui_clip_to "${lines[$row]}" "$((_TUI_COLS - 2))"
      printf ' %s\n' "$_TUI_TEXT" >&2
    done
    tui_rule
    tui_status "$((offset + 1))-$((offset + listh))/$n" 'q 关闭'

    if ! _tui_read_key; then
      break
    fi
    case "$_TUI_KEY" in
      ENTER | q | Q | ESC)
        break
        ;;
      j | J | DOWN)
        ((cursor < n - 1)) && cursor=$((cursor + 1))
        ;;
      k | K | UP)
        ((cursor > 0)) && cursor=$((cursor - 1))
        ;;
      SPACE)
        ((cursor + listh < n)) && cursor=$((cursor + listh))
        ;;
    esac
  done
  tui_end
  return "$TUI_OK"
}

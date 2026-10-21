# 按键读取：把转义序列解码成语义键名，其余按键保留原字符。

_tui_decode_key() {
  local first=$1 next=${2:-} third=${3:-}
  if [[ "$first" == $'\033' ]]; then
    if [[ "$next" == '[' ]]; then
      case "$third" in
        A) _TUI_KEY=UP ;;
        B) _TUI_KEY=DOWN ;;
        C) _TUI_KEY=RIGHT ;;
        D) _TUI_KEY=LEFT ;;
        *) _TUI_KEY=IGNORE ;;
      esac
    else
      _TUI_KEY=ESC
    fi
  elif [[ -z "$first" ]]; then
    _TUI_KEY=ENTER
  elif [[ "$first" == ' ' ]]; then
    _TUI_KEY=SPACE
  else
    _TUI_KEY=$first
  fi
  return 0
}

_tui_read_key() {
  local first='' next='' third=''
  if ! IFS= read -rsn1 first; then
    _TUI_KEY=EOF
    return 1
  fi
  if [[ "$first" == $'\033' ]]; then
    IFS= read -rsn1 -t "$TUI_ESC_TIMEOUT" next || next=''
    if [[ "$next" == '[' ]]; then
      IFS= read -rsn1 -t "$TUI_ESC_TIMEOUT" third || third=''
    fi
  fi
  _tui_decode_key "$first" "$next" "$third"
  return 0
}

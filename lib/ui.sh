# 通用包装：有终端走 TUI，没有终端退回编号输入；返回码原样透传。

ui_available() { ((${UI_MODE:-0})); }

ui_menu() {
  local title=$1 prompt=$2
  shift 2
  if ui_available; then
    tui_menu "$title" "$prompt" "$@"
  else
    plain_menu "$prompt" "$@"
  fi
}

ui_checklist() {
  local title=$1 prompt=$2
  shift 2
  if ui_available; then
    tui_checklist "$title" "$prompt" "$@"
  else
    plain_checklist "$prompt" "$@"
  fi
}

ui_checklist_all() {
  local title=$1 prompt=$2
  shift 2
  if ui_available; then
    tui_checklist_all "$title" "$prompt" "$@"
  else
    plain_checklist_all "$prompt" "$@"
  fi
}

ui_browse() {
  local title=$1 prompt=$2
  shift 2
  if ui_available; then
    tui_browse "$title" "$prompt" "$@"
  else
    _parse_hotkeys "$@" || return "$TUI_ERROR"
    plain_browse "$prompt" "${_TUI_REST[@]+"${_TUI_REST[@]}"}"
  fi
}

ui_input() {
  local title=$1 prompt=$2 default=${3:-}
  if ui_available; then
    tui_input "$title" "$prompt" "$default"
    return $?
  fi
  printf '%s\n\n' "$prompt" >&2
  printf '默认 [%s]: ' "$default" >&2
  local answer=''
  read -r answer || return "$TUI_CANCEL"
  printf '%s\n' "${answer:-$default}"
  return "$TUI_OK"
}

ui_yesno() {
  local title=$1 prompt=$2
  if ui_available; then
    tui_confirm "$title" "$prompt"
    return $?
  fi
  printf '%s [y/N]: ' "$prompt" >&2
  local answer=''
  read -r answer || return "$TUI_CANCEL"
  [[ "${answer,,}" == y || "${answer,,}" == yes ]]
  return $?
}

ui_pager() {
  local title=$1 prompt=$2
  shift 2
  if ui_available; then
    tui_pager "$title" "$prompt" "$@"
  else
    _parse_hotkeys "$@" || return "$TUI_ERROR"
    if ((_TUI_REST_COUNT != 1)); then
      _tui_error 'ui_pager 需要一个文件路径'
      return "$TUI_ERROR"
    fi
    cat "${_TUI_REST[0]}" || return "$TUI_ERROR"
    return "$TUI_OK"
  fi
}

ui_pager_lines() {
  local title=$1 prompt=$2
  shift 2
  if ui_available; then
    tui_pager_lines "$title" "$prompt" "$@"
  else
    _parse_hotkeys "$@" || return "$TUI_ERROR"
    ((_TUI_REST_COUNT)) && printf '%s\n' "${_TUI_REST[@]}"
    return "$TUI_OK"
  fi
}

ui_wait_key() {
  local prompt=$1
  if ui_available; then
    tui_wait_key "$prompt"
    return $?
  fi
  local answer=''
  IFS= read -r answer || return "$TUI_CANCEL"
  printf '%s\n' "$answer"
  return "$TUI_OK"
}

# 通用包装：有终端走 TUI，没有终端退回编号输入；返回码原样透传。

# 终端探测：三个标准流都连着终端才用界面。只在启动时调用一次，必须在命令替换之外判断：
# 替换里的 stdout 是管道，那时 [[ -t 1 ]] 永远为假，会静默退化成编号输入。
ui_detect() {
  UI_MODE=0
  [[ -t 0 && -t 1 && -t 2 ]] || return 0
  UI_MODE=1
  return 0
}

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

# 可选勾选：和 ui_checklist 一样，只是没勾任何项也按成功返回，stdout 为空。
# 用于「勾了才做、不勾就等于跳过」的场合，免得调用方把空选择当成错误。
ui_checklist_optional() {
  local out='' rc=0
  out=$(ui_checklist "$@") || rc=$?
  case "$rc" in
    "$TUI_OK")
      printf '%s\n' "$out"
      return "$TUI_OK"
      ;;
    "$TUI_EMPTY") return "$TUI_OK" ;;
    *) return "$rc" ;;
  esac
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

# 暂停：等一个按键，按 q 表示退出（返回 1），其余按键返回 0。
# 没有终端时直接返回，不读 stdin，否则会把管道里后面的菜单按键吃掉。
ui_pause() {
  local prompt=${1:-'按回车返回'}
  ui_available || return 0
  local key=''
  key=$(ui_wait_key "$prompt") || return 0
  [[ "$key" == q || "$key" == Q ]] && return 1
  return 0
}


# 通用包装：有终端走 TUI，没有终端退回编号输入；返回码原样透传。

ui_available() { ((${UI_MODE:-0})); }

ui_menu() {
  local title=$1 prompt=$2
  shift 2
  if ui_available; then
    tui_select menu "$title" "$prompt" "$@"
  else
    plain_menu "$prompt" "$@"
  fi
  return $?
}

ui_checklist() {
  local title=$1 prompt=$2
  shift 2
  if ! ui_available; then
    plain_checklist "$prompt" "$@"
    return $?
  fi

  local -a items=()
  local -a selected=()
  while (($# >= 3)); do
    items+=("$1" "$2")
    [[ "$3" == ON ]] && selected+=("$1")
    shift 3
  done

  local TUI_PRESELECT=${TUI_PRESELECT:-}
  ((${#selected[@]})) && TUI_PRESELECT=$(printf '%s\n' "${selected[@]}")
  tui_select checklist "$title" "$prompt" "${items[@]}"
  return $?
}

ui_checklist_all() {
  local title=$1 prompt=$2
  shift 2
  if ! ui_available; then
    plain_checklist "$prompt" "$@"
    return $?
  fi

  local -a items=()
  local -a selected=()
  while (($# >= 3)); do
    items+=("$1" "$2")
    [[ "$3" == ON ]] && selected+=("$1")
    shift 3
  done

  local TUI_PRESELECT=${TUI_PRESELECT:-}
  ((${#selected[@]})) && TUI_PRESELECT=$(printf '%s\n' "${selected[@]}")
  tui_select all "$title" "$prompt" "${items[@]}"
  return $?
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

ui_textbox() {
  local title=$1 file=$2
  if ui_available; then
    tui_textbox "$title" "$file"
    return $?
  fi
  cat "$file" >&2
  return $?
}

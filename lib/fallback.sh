# 没有终端时的编号输入；提示写 stderr，结果写 stdout。

_plain_desc() {
  local text=$1
  if [[ "$text" == *$'\t'* ]]; then
    printf '%s\n      %s' "${text%%$'\t'*}" "${text#*$'\t'}"
  else
    printf '%s' "$text"
  fi
}

plain_menu() {
  local prompt=${1:-}
  shift || true
  local -a tags=()
  local -a descs=()
  while (($# >= 2)); do
    tags+=("$1")
    descs+=("$(_plain_desc "$2")")
    shift 2
  done

  printf '%s\n\n' "$prompt" >&2
  local i
  for i in "${!tags[@]}"; do
    printf '  %2d) %-14s %s\n' "$((i + 1))" "${tags[$i]}" "${descs[$i]}" >&2
  done
  printf '\n编号（回车取消）: ' >&2

  local answer=''
  read -r answer || return "$TUI_CANCEL"
  [[ "$answer" =~ ^[0-9]+$ ]] || return "$TUI_CANCEL"
  ((answer >= 1 && answer <= ${#tags[@]})) || return "$TUI_CANCEL"
  printf '%s\n' "${tags[$((answer - 1))]}"
  return "$TUI_OK"
}

plain_checklist() {
  local prompt=${1:-}
  shift || true
  local -a tags=()
  local -a descs=()
  while (($# >= 3)); do
    tags+=("$1")
    descs+=("$(_plain_desc "$2")")
    shift 3
  done

  printf '%s\n\n' "$prompt" >&2
  local i
  for i in "${!tags[@]}"; do
    printf '  %2d) %-14s %s\n' "$((i + 1))" "${tags[$i]}" "${descs[$i]}" >&2
  done
  printf '\n编号，空格分隔（回车取消）: ' >&2

  local answer=''
  read -r answer || return "$TUI_CANCEL"
  [[ -n "$answer" ]] || return "$TUI_EMPTY"

  local -a picked=()
  local n
  for n in $answer; do
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    ((n >= 1 && n <= ${#tags[@]})) || continue
    picked+=("${tags[$((n - 1))]}")
  done
  ((${#picked[@]})) || return "$TUI_EMPTY"
  printf '%s\n' "${picked[@]}"
  return "$TUI_OK"
}

plain_browse() {
  local prompt=${1:-}
  shift || true
  local -a tags=() primaries=() secondaries=()
  while (($# >= 3)); do
    tags+=("$1")
    primaries+=("$2")
    secondaries+=("$3")
    shift 3
  done

  printf '%s\n\n' "$prompt" >&2
  local i
  for i in "${!tags[@]}"; do
    printf '  %2d) %-14s %s\n' "$((i + 1))" "${primaries[$i]}" "${secondaries[$i]}" >&2
  done
  printf '\n编号（回车取消）: ' >&2

  local answer=''
  read -r answer || return "$TUI_CANCEL"
  [[ "$answer" =~ ^[0-9]+$ ]] || return "$TUI_CANCEL"
  ((answer >= 1 && answer <= ${#tags[@]})) || return "$TUI_CANCEL"
  printf '%s\n' "${tags[$((answer - 1))]}"
  return "$TUI_OK"
}

plain_checklist_all() {
  local prompt=${1:-}
  shift || true
  local -a tags=() texts=() states=()
  while (($# >= 3)); do
    tags+=("$1")
    texts+=("$(_plain_desc "$2")")
    states+=("$3")
    shift 3
  done

  if ((${#tags[@]} == 0)); then
    _tui_error '全部勾选需要成对的标签、文本与状态'
    return "$TUI_ERROR"
  fi

  printf '%s\n\n' "$prompt" >&2
  printf '   0) 全部\n' >&2
  local i
  for i in "${!tags[@]}"; do
    printf '  %2d) %s\n' "$((i + 1))" "${texts[$i]}" >&2
  done
  printf '\n编号，空格分隔（0 表示全部，回车取消）: ' >&2

  local answer=''
  read -r answer || return "$TUI_CANCEL"
  [[ -n "$answer" ]] || return "$TUI_EMPTY"

  local -a picked=()
  local n
  for n in $answer; do
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    if ((n == 0)); then
      printf '%s\n' "${tags[@]}"
      return "$TUI_OK"
    fi
    ((n >= 1 && n <= ${#tags[@]})) || continue
    picked+=("${tags[$((n - 1))]}")
  done
  ((${#picked[@]})) || return "$TUI_EMPTY"
  printf '%s\n' "${picked[@]}"
  return "$TUI_OK"
}

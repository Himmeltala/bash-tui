# 没有终端时的编号输入；提示写 stderr，结果写 stdout。

plain_menu() {
  local prompt=${1:-}
  shift || true
  local -a tags=()
  local -a descs=()
  while (($# >= 2)); do
    tags+=("$1")
    descs+=("$2")
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
    descs+=("$2")
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

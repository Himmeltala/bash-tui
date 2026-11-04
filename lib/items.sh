# 条目文本、命名菜单与标签去重：界面显示的名字与条目标签之间的换算。
# 勾选记忆也在这里：读写同一个文件，供调用方在菜单之间回填上次的选择。

# 条目文本：界面只画主文本与次要文本（中间用制表符分），标签不画；编号回退画标签加说明。
# 名字与标签相同时按模式决定名字写在哪，否则界面上只剩说明、编号里名字重复一遍。
# 结果写进全局 UI_ITEM_TEXT，不用命令替换，免得每个条目起一个子 shell。
UI_ITEM_TEXT=''

ui_item_text() {
  if ui_available; then
    UI_ITEM_TEXT=$1$'\t'${2:-}
  else
    UI_ITEM_TEXT=${2:-}
  fi
  return 0
}

# 命令菜单：标签就是命令名或选项名，界面上主文本写命令名、说明作小字解释。
# 参数与 ui_menu 一样是成对的标签与说明，返回码原样透传。
ui_menu_named() {
  local title=${1:-} prompt=${2:-}
  shift 2 || true
  if (($# == 0 || $# % 2 != 0)); then
    _tui_error 'ui_menu_named 需要成对的命令名与说明'
    return "$TUI_ERROR"
  fi

  local -a items=()
  while (($#)); do
    ui_item_text "$1" "$2"
    items+=("$1" "$UI_ITEM_TEXT")
    shift 2
  done
  ui_menu "$title" "$prompt" "${items[@]}"
}

# 取路径的末尾 k 段，用 / 拼回去。
_ui_tail_segments() {
  local -a parts=()
  IFS='/' read -r -a parts <<< "$1"
  local n=${#parts[@]} k=$2
  ((k > n)) && k=$n
  local i out=''
  for ((i = n - k; i < n; i++)); do
    out+="${out:+/}${parts[$i]}"
  done
  printf '%s\n' "$out"
}

# 同名标签去重：标签重复时界面分不清条目，勾选记录也会互相覆盖。
# 同一组里只要重名就按展示路径的尾巴加长，直到组内两两可分；段数取满仍分不开时补一段哈希。
# 参数是成对的 id 与展示路径，输出与参数同序的标签，每行一个。
ui_unique_tags() {
  if (($# == 0 || $# % 2 != 0)); then
    _tui_error 'ui_unique_tags 需要成对的 id 与展示路径'
    return "$TUI_ERROR"
  fi

  local -a ids=() displays=()
  while (($#)); do
    ids+=("$1")
    displays+=("$2")
    shift 2
  done

  local -i n=${#ids[@]} i j k ok dup
  local -A tail_k=()
  local -A seen=()
  local tail

  # 第一步：给每个重名 id 求统一的尾巴段数，让组内两两可分；段数按组统一，免得同批记录有的两段有的三段。
  # 记 0 表示这个 id 没重名，原样使用。
  for ((i = 0; i < n; i++)); do
    [[ -n "${tail_k[${ids[$i]}]:-}" ]] && continue

    dup=0
    for ((j = 0; j < n; j++)); do
      ((j == i)) && continue
      [[ "${ids[$j]}" == "${ids[$i]}" ]] && { dup=1; break; }
    done
    if ((dup == 0)); then
      tail_k["${ids[$i]}"]=0
      continue
    fi

    for ((k = 1; k <= 20; k++)); do
      seen=()
      ok=1
      for ((j = 0; j < n; j++)); do
        [[ "${ids[$j]}" == "${ids[$i]}" ]] || continue
        tail=$(_ui_tail_segments "${displays[$j]}" "$k")
        # 尾巴跟 id 一字不差等于没加；同一组里两段尾巴撞了也不行
        if [[ "$tail" == "${ids[$i]}" || -n "${seen[$tail]:-}" ]]; then
          ok=0
          break
        fi
        seen[$tail]=1
      done
      ((ok == 1)) && break
    done
    tail_k["${ids[$i]}"]=$k
  done

  local -a tags=()
  local candidate
  for ((i = 0; i < n; i++)); do
    k=${tail_k[${ids[$i]}]}
    if ((k == 0)); then
      tags+=("${ids[$i]}")
      continue
    fi

    candidate="${ids[$i]}@$(_ui_tail_segments "${displays[$i]}" "$k")"
    # 段数取满仍分不开的极端情况，补一段展示路径的哈希兜底
    for ((j = 0; j < ${#tags[@]}; j++)); do
      [[ "${tags[$j]}" == "$candidate" ]] || continue
      candidate="${candidate}#$(printf '%s' "${displays[$i]}" | md5sum | cut -c1-4)"
      break
    done
    tags+=("$candidate")
  done

  printf '%s\n' "${tags[@]}"
  return 0
}

# 勾选记忆：把上次勾选的标签读进 TUI_PRESELECT；文件不在时清空，等同于没有预选。
ui_preselect_load() {
  local file=${1:-}
  TUI_PRESELECT=''
  [[ -n "$file" && -f "$file" ]] || return 0
  TUI_PRESELECT=$(<"$file")
  return 0
}

# 把这次勾选的标签写回文件，目录不存在时先建。
ui_preselect_save() {
  local file=${1:-}
  shift || true
  if [[ -z "$file" ]]; then
    _tui_error 'ui_preselect_save 需要文件路径'
    return "$TUI_ERROR"
  fi

  local dir=${file%/*}
  [[ "$dir" == "$file" ]] || mkdir -p "$dir" 2>/dev/null
  : > "$file" 2>/dev/null || return "$TUI_ERROR"
  (($#)) && printf '%s\n' "$@" >> "$file"
  return 0
}

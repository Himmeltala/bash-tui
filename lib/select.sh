# 列表选择：menu、checklist、all 三种模式共用一套渲染与按键循环。

tui_select() {
  if (($# < 3)); then
    _tui_error 'tui_select 需要模式、标题、提示三个参数'
    return "$TUI_ERROR"
  fi

  local mode=$1 title=$2 prompt=$3
  shift 3

  case "$mode" in
    menu | checklist | all) ;;
    *)
      _tui_error "tui_select 未知模式: $mode"
      return "$TUI_ERROR"
      ;;
  esac

  if ((($# % 2) != 0)); then
    _tui_error 'tui_select 的标签与说明必须成对'
    return "$TUI_ERROR"
  fi

  local n=$(($# / 2))
  if ((n == 0)); then
    _tui_error 'tui_select 的列表为空'
    return "$TUI_ERROR"
  fi

  local -a tags=()
  local -a displays=()
  while (($#)); do
    tags+=("$1")
    displays+=("$2")
    shift 2
  done

  local is_all=0 base=0
  if [[ "$mode" == all ]]; then
    is_all=1
    base=1
  fi
  local rows=$((n + is_all))
  local cursor=0
  local offset=0
  local i

  local -a on=()
  local all_on=0
  if [[ "$mode" != menu ]]; then
    local -A saved=()
    local line
    if [[ -n ${TUI_PRESELECT:-} ]]; then
      while IFS= read -r line; do
        [[ -n "$line" ]] && saved[$line]=1
      done <<< "$TUI_PRESELECT"
    fi
    for ((i = 0; i < n; i++)); do
      on[i]=0
      [[ -n "${saved[${tags[$i]}]:-}" ]] && on[i]=1
    done
    all_on=1
    for ((i = 0; i < n; i++)); do
      if ((on[i] == 0)); then
        all_on=0
        break
      fi
    done
  fi

  local rc=$TUI_OK
  local selected=0
  local footer=''
  local listh=0
  local row=0
  local idx=0
  local mark=''

  tui_begin
  while :; do
    tui_size
    listh=$((_TUI_LINES - _TUI_CHROME_LINES))
    ((listh > rows)) && listh=$rows
    ((listh < 1)) && listh=1
    _tui_clamp_window "$cursor" "$offset" "$listh" "$rows"
    cursor=$_TUI_CURSOR
    offset=$_TUI_OFFSET

    tui_clear
    tui_title "$title"
    tui_subtitle "$prompt"
    if [[ "$mode" == menu ]]; then
      tui_hint '↑↓' '移动' '回车' '选择' 'q' '取消'
    else
      tui_hint '↑↓' '移动' '空格' '勾选' '回车' '确认' '←' '返回' 'q' '取消'
    fi
    tui_rule

    for ((row = offset; row < offset + listh && row < rows; row++)); do
      if [[ "$mode" == menu ]]; then
        idx=$((row - base))
        tui_row "$((row == cursor))" '' "${tags[$idx]}" "${displays[$idx]}"
        continue
      fi

      if ((is_all && row == 0)); then
        ((all_on)) && mark='[x]' || mark='[ ]'
        tui_row "$((row == cursor))" "$mark" "$TUI_LABEL_ALL" "$TUI_LABEL_ALL_DESC"
      else
        idx=$((row - base))
        ((on[idx])) && mark='[x]' || mark='[ ]'
        tui_row "$((row == cursor))" "$mark" "${tags[$idx]}" "${displays[$idx]}"
      fi
    done

    tui_rule
    selected=0
    for ((i = 0; i < n; i++)); do
      ((on[i])) && selected=$((selected + 1))
    done
    if [[ "$mode" == menu ]]; then
      footer=$((cursor + 1))"/$n"
    else
      footer="已选 $selected/$n"
      ((offset > 0)) && footer+='   ↑ 更多'
      ((offset + listh < rows)) && footer+='   ↓ 更多'
    fi
    tui_status "$footer" 'q 取消'

    if ! _tui_read_key; then
      rc=$TUI_CANCEL
      break
    fi

    case "$_TUI_KEY" in
      ENTER)
        if [[ "$mode" == menu ]]; then
          printf '%s\n' "${tags[$cursor]}"
          rc=$TUI_OK
        elif ((selected == 0)); then
          rc=$TUI_EMPTY
        fi
        break
        ;;
      SPACE | x | X)
        [[ "$mode" == menu ]] && continue
        if ((is_all && cursor == 0)); then
          if ((all_on)); then
            for ((i = 0; i < n; i++)); do on[i]=0; done
            all_on=0
          else
            for ((i = 0; i < n; i++)); do on[i]=1; done
            all_on=1
          fi
        else
          idx=$((cursor - base))
          on[idx]=$((1 - on[idx]))
          all_on=1
          for ((i = 0; i < n; i++)); do
            if ((on[i] == 0)); then
              all_on=0
              break
            fi
          done
        fi
        ;;
      j | J)
        ((cursor < rows - 1)) && cursor=$((cursor + 1))
        ;;
      k | K)
        ((cursor > 0)) && cursor=$((cursor - 1))
        ;;
      UP)
        ((cursor > 0)) && cursor=$((cursor - 1))
        ;;
      DOWN)
        ((cursor < rows - 1)) && cursor=$((cursor + 1))
        ;;
      q | Q)
        rc=$TUI_CANCEL
        break
        ;;
      b | B | $'\177' | $'\b' | LEFT | ESC)
        rc=$TUI_BACK
        break
        ;;
    esac
  done

  tui_end
  ((rc == TUI_OK)) || return "$rc"
  [[ "$mode" == menu ]] && return "$TUI_OK"

  local -a picked=()
  for ((i = 0; i < n; i++)); do
    ((on[i])) && picked+=("${tags[$i]}")
  done
  ((${#picked[@]})) || return "$TUI_EMPTY"
  printf '%s\n' "${picked[@]}"
  return "$TUI_OK"
}

# 视图状态与条目模型：engine 与 widgets 共用。

_TUI_VIEW_MODE=''
_TUI_VIEW_TITLE=''
_TUI_VIEW_SUBTITLE=''
_TUI_ITEMS_TAGS=()
_TUI_ITEMS_PRIMARY=()
_TUI_ITEMS_SECONDARY=()
_TUI_ITEMS_STATE=()
_TUI_ITEMS_COUNT=0
_TUI_SELECTED=0

_tui_view_reset() {
  _TUI_VIEW_MODE=''
  _TUI_VIEW_TITLE=''
  _TUI_VIEW_SUBTITLE=''
  _TUI_ITEMS_TAGS=()
  _TUI_ITEMS_PRIMARY=()
  _TUI_ITEMS_SECONDARY=()
  _TUI_ITEMS_STATE=()
  _TUI_ITEMS_COUNT=0
  _TUI_SELECTED=0
  _TUI_HOTKEY_KEYS=()
  _TUI_HOTKEY_ACTIONS=()
  _TUI_HOTKEY_COUNT=0
  _TUI_HOTKEY_ACTION=''
  _TUI_ACTION=''
  _TUI_ACTION_ARG=''
  return 0
}

_tui_validate_label() {
  case "$1" in
    @hotkey:*)
      _tui_error "标签或动作不能以 @hotkey: 开头: $1"
      return "$TUI_ERROR"
      ;;
  esac
  return 0
}

_tui_item_add() {
  local tag=$1 text=$2 state=${3:-0}
  local primary=${text%%$'\t'*}
  local secondary=''
  [[ "$text" == *$'\t'* ]] && secondary=${text#*$'\t'}

  _tui_validate_label "$tag" || return "$TUI_ERROR"
  _TUI_ITEMS_TAGS+=("$tag")
  _TUI_ITEMS_PRIMARY+=("$primary")
  _TUI_ITEMS_SECONDARY+=("$secondary")
  _TUI_ITEMS_STATE+=("$state")
  _TUI_ITEMS_COUNT=$((_TUI_ITEMS_COUNT + 1))
  return 0
}

_tui_selected_count() {
  local i
  _TUI_SELECTED=0
  for ((i = 0; i < _TUI_ITEMS_COUNT; i++)); do
    ((_TUI_ITEMS_STATE[i])) && _TUI_SELECTED=$((_TUI_SELECTED + 1))
  done
  return 0
}

_tui_chrome_height() {
  local subtitle=${1:-}
  local h=8
  [[ -n "$subtitle" ]] && h=$((h + 1))
  printf '%s\n' "$h"
}

# 热键与按键分派：按键到动作的纯计算，不涉及渲染与读取。
_TUI_HOTKEY_KEYS=()
_TUI_HOTKEY_ACTIONS=()
_TUI_HOTKEY_COUNT=0
_TUI_HOTKEY_ACTION=''
_TUI_ACTION=''
_TUI_ACTION_ARG=''

_tui_hotkey_add() {
  local key=$1 action=$2
  _tui_validate_label "$action" || return "$TUI_ERROR"
  _TUI_HOTKEY_KEYS+=("$key")
  _TUI_HOTKEY_ACTIONS+=("$action")
  _TUI_HOTKEY_COUNT=$((_TUI_HOTKEY_COUNT + 1))
  return 0
}

_tui_hotkey_match() {
  local key=$1 i k
  for ((i = 0; i < _TUI_HOTKEY_COUNT; i++)); do
    k=${_TUI_HOTKEY_KEYS[$i]}
    if [[ ${#k} -eq 1 && ${#key} -eq 1 ]]; then
      if [[ "${k,,}" == "${key,,}" ]]; then
        _TUI_HOTKEY_ACTION=${_TUI_HOTKEY_ACTIONS[$i]}
        return 0
      fi
    elif [[ "$k" == "$key" ]]; then
      _TUI_HOTKEY_ACTION=${_TUI_HOTKEY_ACTIONS[$i]}
      return 0
    fi
  done
  return 1
}

_tui_engine_handle_key() {
  local mode=$1 key=$2
  _TUI_ACTION=''
  _TUI_ACTION_ARG=''

  if _tui_hotkey_match "$key"; then
    _TUI_ACTION='hotkey'
    _TUI_ACTION_ARG=$_TUI_HOTKEY_ACTION
    return 0
  fi

  case "$key" in
    UP | k | K) _TUI_ACTION='move-up' ;;
    DOWN | j | J) _TUI_ACTION='move-down' ;;
    '[') _TUI_ACTION='page-up' ;;
    ']') _TUI_ACTION='page-down' ;;
    q | Q | ESC | LEFT) _TUI_ACTION='cancel' ;;
    ENTER)
      case "$mode" in
        menu | browse | multi | multi_all) _TUI_ACTION='select' ;;
      esac
      ;;
    SPACE)
      case "$mode" in
        multi | multi_all) _TUI_ACTION='toggle' ;;
        pager) _TUI_ACTION='page-down' ;;
      esac
      ;;
  esac
  return 0
}

_tui_engine_render_rows() {
  local mode=$1 cursor=$2 offset=$3 listh=$4 total=$5
  local row idx mark primary secondary

  for ((row = offset; row < offset + listh && row < total; row++)); do
    if [[ "$mode" == 'multi_all' ]]; then
      if ((row == 0)); then
        _tui_all_selected && mark='[x]' || mark='[ ]'
        tui_row "$((row == cursor))" "$mark" "$TUI_LABEL_ALL" "$TUI_LABEL_ALL_DESC"
        continue
      fi
      idx=$((row - 1))
    else
      idx=$row
    fi

    mark=''
    if [[ "$mode" == 'multi' || "$mode" == 'multi_all' ]]; then
      ((_TUI_ITEMS_STATE[idx])) && mark='[x]' || mark='[ ]'
    fi
    primary=${_TUI_ITEMS_PRIMARY[$idx]}
    secondary=${_TUI_ITEMS_SECONDARY[$idx]}
    tui_row "$((row == cursor))" "$mark" "$primary" "$secondary"
  done
}

_tui_engine_hint() {
  local mode=$1 i
  local -a pairs=()

  case "$mode" in
    menu) pairs=( '↑↓' '移动' '回车' '选择' ) ;;
    multi | multi_all) pairs=( '↑↓' '移动' '空格' '勾选' '回车' '确认' ) ;;
    browse) pairs=( '↑↓' '选择' '回车' '操作' ) ;;
    pager) pairs=( '↑↓' '滚动' '空格' '翻页' ) ;;
  esac

  for ((i = 0; i < _TUI_HOTKEY_COUNT; i++)); do
    pairs+=( "${_TUI_HOTKEY_KEYS[$i]}" "${_TUI_HOTKEY_ACTIONS[$i]}" )
  done
  pairs+=( 'q' '返回' )
  tui_hint "${pairs[@]}"
}

_tui_engine_status() {
  local mode=$1 cursor=$2 offset=$3 listh=$4 total=$5 selected=$6
  local first last footer
  if [[ "$mode" == 'pager' ]]; then
    if ((total == 0)); then
      tui_status '0/0' 'q 返回'
      return 0
    fi
    first=$((offset + 1))
    last=$((offset + listh))
    ((last > total)) && last=$total
    tui_status "$first-$last/$total" 'q 返回'
    return 0
  fi
  if [[ "$mode" == 'multi' || "$mode" == 'multi_all' ]]; then
    tui_status "已选 $selected/$_TUI_ITEMS_COUNT" 'q 取消'
    return 0
  fi
  if [[ "$mode" == 'browse' ]]; then
    tui_status "$((cursor + 1))/$total" 'q 返回'
    return 0
  fi
  tui_status "$((cursor + 1))/$total" 'q 取消'
}

_tui_engine() {
  local mode=$_TUI_VIEW_MODE
  local total=$_TUI_ITEMS_COUNT
  local cursor=0 offset=0 listh=0 row key rc selected=0

  [[ "$mode" == 'pager' ]] && total=$_TUI_CONTENT_COUNT
  [[ "$mode" == 'multi_all' ]] && total=$((total + 1))
  tui_begin
  while :; do
    tui_size
    listh=$((_TUI_LINES - $(_tui_chrome_height "$_TUI_VIEW_SUBTITLE")))
    ((listh < 1)) && listh=1
    ((listh > total)) && listh=$total
    _tui_clamp_window "$cursor" "$offset" "$listh" "$total"
    cursor=$_TUI_CURSOR
    offset=$_TUI_OFFSET

    _tui_selected_count
    selected=$_TUI_SELECTED

    tui_frame_begin
    tui_clear
    tui_title "$_TUI_VIEW_TITLE"
    tui_subtitle "$_TUI_VIEW_SUBTITLE"
    _tui_engine_hint "$mode"
    tui_rule
    if [[ "$mode" == 'pager' ]]; then
      _tui_engine_render_lines "$offset" "$listh" "$total"
    else
      _tui_engine_render_rows "$mode" "$cursor" "$offset" "$listh" "$total"
    fi
    tui_rule
    _tui_engine_status "$mode" "$cursor" "$offset" "$listh" "$total" "$selected"
    tui_frame_end

    if ! _tui_read_key; then
      rc=$TUI_CANCEL
      break
    fi
    _tui_engine_handle_key "$mode" "$_TUI_KEY"
    case "$_TUI_ACTION" in
      hotkey)
        printf '@hotkey:%s\n' "$_TUI_ACTION_ARG"
        rc=$TUI_OK
        break
        ;;
      cancel)
        if [[ "$mode" == 'pager' ]]; then
          rc=$TUI_OK
        else
          rc=$TUI_CANCEL
        fi
        break
        ;;
      move-up) ((cursor > 0)) && cursor=$((cursor - 1)) ;;
      move-down) ((cursor < total - 1)) && cursor=$((cursor + 1)) ;;
      page-up) ((cursor >= listh)) && cursor=$((cursor - listh)) || cursor=0; _TUI_PAGE_ALIGN=1 ;;
      page-down) cursor=$((cursor + listh)); ((cursor >= total)) && cursor=$((total - 1)); _TUI_PAGE_ALIGN=1 ;;
      toggle) _tui_engine_toggle "$mode" "$cursor" ;;
      select)
        case "$mode" in
          menu | browse)
            printf '%s\n' "${_TUI_ITEMS_TAGS[$cursor]}"
            rc=$TUI_OK
            break
            ;;
          multi | multi_all)
            _tui_selected_count
            if ((_TUI_SELECTED == 0)); then
              rc=$TUI_EMPTY
            else
              _tui_emit_selected
              rc=$TUI_OK
            fi
            break
            ;;
        esac
        ;;
    esac
  done
  tui_end
  return "$rc"
}

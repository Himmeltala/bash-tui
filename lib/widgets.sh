# 视图适配层：把公开接口转成 engine 状态。

_parse_hotkeys() {
  local -a rest=()
  local key action label
  while (($#)); do
    case "$1" in
      --hotkey)
        (($# >= 3)) || { _tui_error '--hotkey 需要键与动作'; return "$TUI_ERROR"; }
        key=$2 action=$3 label=$3
        shift 3
        if (($#)) && [[ "$1" != '--hotkey' && "$1" != '--' ]]; then
          label=$1
          shift
        fi
        _tui_hotkey_add "$key" "$action" "$label" || return "$TUI_ERROR"
        ;;
      --)
        shift
        rest=("$@")
        break
        ;;
      *)
        _tui_error "未知参数：$1"
        return "$TUI_ERROR"
        ;;
    esac
  done
  _TUI_REST=("${rest[@]+"${rest[@]}"}")
  _TUI_REST_COUNT=${#rest[@]}
  return 0
}

tui_menu() {
  local title=$1 prompt=$2
  shift 2
  if (($# == 0 || $# % 2 != 0)); then
    _tui_error 'tui_menu 需要成对的标签与文本'
    return "$TUI_ERROR"
  fi

  _tui_view_reset
  _TUI_VIEW_MODE='menu'
  _TUI_VIEW_TITLE=$title
  _TUI_VIEW_SUBTITLE=$prompt
  while (($#)); do
    _tui_item_add "$1" "$2" '' || return "$TUI_ERROR"
    shift 2
  done
  _tui_engine
}

tui_browse() {
  local title=$1 prompt=$2
  shift 2
  _tui_view_reset
  _TUI_VIEW_MODE='browse'
  _TUI_VIEW_TITLE=$title
  _TUI_VIEW_SUBTITLE=$prompt

  _parse_hotkeys "$@" || return "$TUI_ERROR"
  if ((_TUI_REST_COUNT == 0 || _TUI_REST_COUNT % 3 != 0)); then
    _tui_error 'tui_browse 需要成对的标签、主文本与说明文本'
    return "$TUI_ERROR"
  fi
  set -- "${_TUI_REST[@]}"
  while (($#)); do
    _tui_item_add "$1" "$2" '' || return "$TUI_ERROR"
    _TUI_ITEMS_SECONDARY[$((_TUI_ITEMS_COUNT - 1))]=$3
    shift 3
  done
  _tui_engine
}

_tui_checklist_common() {
  local mode=$1 title=$2 prompt=$3
  shift 3
  if (($# == 0 || $# % 3 != 0)); then
    _tui_error '勾选需要成对的标签、文本与状态'
    return "$TUI_ERROR"
  fi

  _tui_view_reset
  _TUI_VIEW_MODE=$mode
  _TUI_VIEW_TITLE=$title
  _TUI_VIEW_SUBTITLE=$prompt

  local tag text state
  while (($#)); do
    tag=$1 text=$2 state=$3
    case "$state" in
      ON) state=1 ;;
      OFF) state=0 ;;
      *)
        _tui_error "状态只能是 ON 或 OFF：$state"
        return "$TUI_ERROR"
        ;;
    esac
    _tui_item_add "$tag" "$text" "$state" || return "$TUI_ERROR"
    shift 3
  done

  if [[ -n ${TUI_PRESELECT:-} ]]; then
    local preselected i
    while IFS= read -r preselected; do
      [[ -n "$preselected" ]] || continue
      for ((i = 0; i < _TUI_ITEMS_COUNT; i++)); do
        if [[ "${_TUI_ITEMS_TAGS[$i]}" == "$preselected" ]]; then
          _TUI_ITEMS_STATE[i]=1
          break
        fi
      done
    done <<< "$TUI_PRESELECT"
  fi

  _tui_engine
}

tui_checklist() {
  _tui_checklist_common multi "$@"
}

tui_checklist_all() {
  _tui_checklist_common multi_all "$@"
}

tui_pager() {
  local title=$1 prompt=$2
  shift 2
  _tui_view_reset
  _TUI_VIEW_MODE='pager'
  _TUI_VIEW_TITLE=$title
  _TUI_VIEW_SUBTITLE=$prompt

  _parse_hotkeys "$@" || return "$TUI_ERROR"
  if ((_TUI_REST_COUNT != 1)); then
    _tui_error 'tui_pager 需要一个文件路径'
    return "$TUI_ERROR"
  fi
  local file=${_TUI_REST[0]}
  if [[ ! -f "$file" || ! -r "$file" ]]; then
    _tui_error "读不到文件：$file"
    return "$TUI_ERROR"
  fi
  mapfile -t _TUI_CONTENT_LINES < "$file"
  _TUI_CONTENT_COUNT=${#_TUI_CONTENT_LINES[@]}
  _tui_engine
}

tui_pager_lines() {
  local title=$1 prompt=$2
  shift 2
  _tui_view_reset
  _TUI_VIEW_MODE='pager'
  _TUI_VIEW_TITLE=$title
  _TUI_VIEW_SUBTITLE=$prompt

  _parse_hotkeys "$@" || return "$TUI_ERROR"
  _TUI_CONTENT_LINES=("${_TUI_REST[@]+"${_TUI_REST[@]}"}")
  _TUI_CONTENT_COUNT=${#_TUI_CONTENT_LINES[@]}
  _tui_engine
}

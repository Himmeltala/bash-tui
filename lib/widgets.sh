# 视图适配层：把公开接口转成 engine 状态。

_parse_hotkeys() {
  local -a rest=()
  while (($#)); do
    case "$1" in
      --hotkey)
        (($# >= 3)) || { _tui_error '--hotkey 需要键与动作'; return "$TUI_ERROR"; }
        _tui_hotkey_add "$2" "$3" || return "$TUI_ERROR"
        shift 3
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

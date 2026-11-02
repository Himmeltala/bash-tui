# 视图状态与条目模型：engine 与 widgets 共用。

_TUI_VIEW_MODE=''
_TUI_VIEW_TITLE=''
_TUI_VIEW_SUBTITLE=''
_TUI_ITEMS_TAGS=()
_TUI_ITEMS_PRIMARY=()
_TUI_ITEMS_SECONDARY=()
_TUI_ITEMS_STATE=()
_TUI_ITEMS_COUNT=0

_tui_view_reset() {
  _TUI_VIEW_MODE=''
  _TUI_VIEW_TITLE=''
  _TUI_VIEW_SUBTITLE=''
  _TUI_ITEMS_TAGS=()
  _TUI_ITEMS_PRIMARY=()
  _TUI_ITEMS_SECONDARY=()
  _TUI_ITEMS_STATE=()
  _TUI_ITEMS_COUNT=0
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

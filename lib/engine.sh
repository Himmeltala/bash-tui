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

#!/usr/bin/env bash
# 无终端自测：纯计算、回退层与参数校验。

set -uo pipefail

_root=${BASH_SOURCE[0]%/*}
[[ "$_root" == "${BASH_SOURCE[0]}" ]] && _root='.'
_root=$(cd "$_root/.." && pwd)

# shellcheck source=/dev/null
source "$_root/bash-tui.sh"

_passed=0
_failed=0

check_equal() {
  local name=$1 expected=$2 actual=$3
  if [[ "$expected" == "$actual" ]]; then
    _passed=$((_passed + 1))
  else
    printf 'FAIL %s\n  expected: %q\n  actual:   %q\n' "$name" "$expected" "$actual"
    _failed=$((_failed + 1))
  fi
}

check_status() {
  local name=$1 expected=$2 actual=$3
  if ((expected == actual)); then
    _passed=$((_passed + 1))
  else
    printf 'FAIL %s\n  expected status: %s\n  actual status:   %s\n' "$name" "$expected" "$actual"
    _failed=$((_failed + 1))
  fi
}

check_equal 'core: 返回码' '0 1 2 3 4' "$TUI_OK $TUI_CANCEL $TUI_EMPTY $TUI_ERROR $TUI_BACK"
check_equal 'core: 默认尺寸' '24 100' "$_TUI_DEFAULT_LINES $_TUI_DEFAULT_COLS"

_tui_measure 'abc'
check_equal 'render: ASCII 宽度' '3' "$_TUI_WIDTH"
_tui_measure '中文'
check_equal 'render: 中文宽度' '4' "$_TUI_WIDTH"
_tui_measure 'a中'
check_equal 'render: 中英混排宽度' '3' "$_TUI_WIDTH"
_tui_measure ''
check_equal 'render: 空串宽度' '0' "$_TUI_WIDTH"

_tui_clip_to 'abcdef' 3
check_equal 'render: ASCII 截断' 'abc' "$_TUI_TEXT"
_tui_clip_to '中文中文' 3
check_equal 'render: 中文截断整字' '中' "$_TUI_TEXT"
_tui_clip_to '中文中文' 3
check_equal 'render: 中文截断宽度' '2' "$_TUI_WIDTH"
_tui_clip_to 'abcdef' 3
check_equal 'render: ASCII 截断宽度' '3' "$_TUI_WIDTH"
_tui_clip_to 'abcdef' 6
check_equal 'render: 不截断宽度' '6' "$_TUI_WIDTH"
_tui_clip_to 'abc' 0
check_equal 'render: 宽度为零截断' '' "$_TUI_TEXT"

_tui_decode_key $'\033' '[' 'A'
check_equal 'key: 上方向键' 'UP' "$_TUI_KEY"
_tui_decode_key $'\033' '[' 'B'
check_equal 'key: 下方向键' 'DOWN' "$_TUI_KEY"
_tui_decode_key $'\033' '[' 'C'
check_equal 'key: 右方向键' 'RIGHT' "$_TUI_KEY"
_tui_decode_key $'\033' '[' 'D'
check_equal 'key: 左方向键' 'LEFT' "$_TUI_KEY"
_tui_decode_key ''
check_equal 'key: 回车' 'ENTER' "$_TUI_KEY"
_tui_decode_key ' '
check_equal 'key: 空格' 'SPACE' "$_TUI_KEY"
_tui_decode_key 'x'
check_equal 'key: 普通字符' 'x' "$_TUI_KEY"
_tui_decode_key $'\033' '' ''
check_equal 'key: 单独 ESC' 'ESC' "$_TUI_KEY"
_tui_decode_key $'\033' '[' 'H'
check_equal 'key: 未知 CSI 忽略' 'IGNORE' "$_TUI_KEY"
_tui_decode_key $'\033' '[' ''
check_equal 'key: 截断 CSI 忽略' 'IGNORE' "$_TUI_KEY"

_tui_clamp_window 0 0 5 20
check_equal 'scroll: 上边界' '0 0' "$_TUI_CURSOR $_TUI_OFFSET"
_tui_clamp_window 10 0 5 20
check_equal 'scroll: 下边界' '10 6' "$_TUI_CURSOR $_TUI_OFFSET"
_tui_clamp_window 5 8 5 20
check_equal 'scroll: 光标回到窗口' '5 5' "$_TUI_CURSOR $_TUI_OFFSET"
_tui_clamp_window 2 0 5 3
check_equal 'scroll: 列表短于窗口' '2 0' "$_TUI_CURSOR $_TUI_OFFSET"

_TUI_PAGE_ALIGN=1
_tui_clamp_window 15 0 15 80
check_equal 'scroll: 下翻一页对齐' '15 15' "$_TUI_CURSOR $_TUI_OFFSET"
_TUI_PAGE_ALIGN=1
_tui_clamp_window 79 60 15 80
check_equal 'scroll: 末页对齐' '79 65' "$_TUI_CURSOR $_TUI_OFFSET"
_TUI_PAGE_ALIGN=1
_tui_clamp_window 0 15 15 80
check_equal 'scroll: 上翻一页对齐' '0 0' "$_TUI_CURSOR $_TUI_OFFSET"
_TUI_PAGE_ALIGN=0

tui_select wrong '标题' '提示' a A >/dev/null 2>&1
check_status 'select: 未知模式' "$TUI_ERROR" "$?"

tui_select menu '标题' '提示' a >/dev/null 2>&1
check_status 'select: 参数不成对' "$TUI_ERROR" "$?"

tui_select menu '标题' '提示' >/dev/null 2>&1
check_status 'select: 空列表' "$TUI_ERROR" "$?"

tui_textbox '标题' /nonexistent/file >/dev/null 2>&1
check_status 'view: 文件不可读' "$TUI_ERROR" "$?"

tui_textbox '标题' /tmp >/dev/null 2>&1 </dev/null
check_status 'view: 目录不是文件' "$TUI_ERROR" "$?"

tui_confirm '' >/dev/null 2>&1
check_status 'dialog: 缺少提示' "$TUI_ERROR" "$?"

_out=$(printf '2\n' | plain_menu '选择' a A b B)
check_equal 'fallback: 编号单选' 'b' "$_out"

printf '9\n' | plain_menu '选择' a A b B >/dev/null 2>&1
check_status 'fallback: 越界编号' "$TUI_CANCEL" "$?"

printf '\n' | plain_menu '选择' a A b B >/dev/null 2>&1
check_status 'fallback: 回车取消' "$TUI_CANCEL" "$?"

_out=$(printf '1 3\n' | plain_checklist '选择' a A OFF b B OFF c C OFF)
check_equal 'fallback: 编号复选' $'a\nc' "$_out"

printf '\n' | plain_checklist '选择' a A OFF >/dev/null 2>&1
check_status 'fallback: 复选空输入' "$TUI_EMPTY" "$?"

printf '9\n' | plain_checklist '选择' a A OFF >/dev/null 2>&1
check_status 'fallback: 复选全部非法' "$TUI_EMPTY" "$?"

check_equal 'fallback: 菜单返回标签' 'a' "$(printf '1\n' | plain_menu '选一个' a '选项 A' b '选项 B' 2>/dev/null)"
check_equal 'fallback: 浏览返回标签' 'p:1' "$(printf '1\n' | plain_browse '选端口' p:1 'TCP' '127.0.0.1:1' 2>/dev/null)"
check_equal 'fallback: 全选输出两行' $'a\nb' "$(printf '0\n' | plain_checklist_all '全选' a 'A' ON b 'B' OFF 2>/dev/null)"
check_equal 'fallback: 制表符转两行' $'主\n      次' "$(_plain_desc $'主\t次')"
printf '\n' | plain_checklist '提示' a 'A' OFF >/dev/null 2>&1
check_status 'fallback: 空勾选返回 EMPTY' "$TUI_EMPTY" "$?"
printf '\n' | plain_checklist_all '提示' a 'A' OFF >/dev/null 2>&1
check_status 'fallback: 全选空输入返回 EMPTY' "$TUI_EMPTY" "$?"
printf '' | plain_checklist_all '提示' a 'A' OFF >/dev/null 2>&1
check_status 'fallback: 全选 EOF 返回 CANCEL' "$TUI_CANCEL" "$?"
printf '' | plain_menu '提示' a 'A' >/dev/null 2>&1
check_status 'fallback: 菜单 EOF 返回 CANCEL' "$TUI_CANCEL" "$?"
UI_MODE=0
printf '' | ui_wait_key '继续' >/dev/null 2>&1
check_status 'fallback: 等待按键 EOF 返回 CANCEL' "$TUI_CANCEL" "$?"
check_equal 'fallback: 等待按键' 'q' "$(printf 'q\n' | ui_wait_key '继续' 2>/dev/null)"

tmp=$(mktemp)
printf 'a\nb\n' > "$tmp"
check_equal 'fallback: 分页输出' $'a\nb' "$(ui_pager '标题' '提示' -- "$tmp" 2>/dev/null)"
rm -f "$tmp"

UI_MODE=0
_out=$(printf '1\n' | ui_menu '标题' '提示' a A b B)
check_equal 'ui: 单选回退' 'a' "$_out"

_out=$(printf '2\n' | ui_input '标题' '提示' 'z')
check_equal 'ui: 输入回退' '2' "$_out"

_out=$(printf 'y\n' | ui_yesno '标题' '提示'; printf '%s' "$?")
check_equal 'ui: 确认回退' '0' "$_out"

_tui_view_reset
_tui_item_add 'p:TCP:8080' $'8080/TCP\t0.0.0.0:8080 java' ''
check_equal 'items: 标签' 'p:TCP:8080' "${_TUI_ITEMS_TAGS[0]}"
check_equal 'items: 主文本' '8080/TCP' "${_TUI_ITEMS_PRIMARY[0]}"
check_equal 'items: 说明文本' '0.0.0.0:8080 java' "${_TUI_ITEMS_SECONDARY[0]}"
check_equal 'items: 数量' '1' "$_TUI_ITEMS_COUNT"

_tui_validate_label '@hotkey:kill'
check_status 'items: 保留前缀被拒' "$TUI_ERROR" "$?"

_tui_hotkey_add 'u' 'udp'
_tui_hotkey_add 'LEFT' 'back'
_tui_hotkey_match 'U'
check_status 'hotkey: 单字符大小写不敏感' '0' "$?"
check_equal 'hotkey: 命中动作' 'udp' "$_TUI_HOTKEY_ACTION"
_tui_hotkey_match 'u'
check_status 'hotkey: 小写命中' '0' "$?"
_tui_hotkey_match 'x'
check_status 'hotkey: 未命中' '1' "$?"
_tui_hotkey_match 'LEFT'
check_equal 'hotkey: 命名键精确匹配' 'back' "$_TUI_HOTKEY_ACTION"

_tui_engine_handle_key browse 'k'
check_equal 'key: 向上' 'move-up' "$_TUI_ACTION"
_tui_engine_handle_key menu 'ENTER'
check_equal 'key: 回车选择' 'select' "$_TUI_ACTION"
_tui_engine_handle_key multi 'SPACE'
check_equal 'key: 空格勾选' 'toggle' "$_TUI_ACTION"
_tui_engine_handle_key pager 'SPACE'
check_equal 'key: 分页空格翻页' 'page-down' "$_TUI_ACTION"
_tui_engine_handle_key pager 'q'
check_equal 'key: q 取消' 'cancel' "$_TUI_ACTION"

_tui_view_reset
_TUI_VIEW_MODE='menu'
_tui_item_add 'a' '选项 A' ''
_tui_item_add 'b' '选项 B' ''
check_equal 'menu: 条目数' '2' "$_TUI_ITEMS_COUNT"
_tui_engine_handle_key menu 'ENTER'
check_equal 'menu: 回车动作' 'select' "$_TUI_ACTION"

tui_menu '空菜单' '提示'
check_status 'menu: 空列表报错' "$TUI_ERROR" "$?"
tui_browse '空浏览' '提示' --
check_status 'browse: 空列表报错' "$TUI_ERROR" "$?"

printf 'q' | tui_menu 't' 'p' a 'A' >/dev/null 2>&1
check_status 'menu: 非空取消' "$TUI_CANCEL" "$?"

_tui_view_reset
_TUI_VIEW_MODE='multi'
_tui_item_add 'a' 'A' 1
_tui_item_add 'b' 'B' 0
_tui_selected_count
check_equal 'checklist: 已选数' '1' "$_TUI_SELECTED"
_tui_engine_toggle multi 1
_tui_selected_count
check_equal 'checklist: 勾选后已选数' '2' "$_TUI_SELECTED"
_tui_emit_selected >/dev/null
check_equal 'checklist: 输出两行' '2' "$( _tui_emit_selected | wc -l )"

tui_checklist '空勾选' '提示'
check_status 'checklist: 空列表报错' "$TUI_ERROR" "$?"
tui_checklist '非法状态' '提示' a 'A' MAYBE
check_status 'checklist: 非法状态报错' "$TUI_ERROR" "$?"

_tui_view_reset
_TUI_VIEW_MODE='pager'
_TUI_CONTENT_LINES=('第一行' '第二行')
_TUI_CONTENT_COUNT=2
_tui_engine_handle_key pager ']'
check_equal 'pager: 下翻页动作' 'page-down' "$_TUI_ACTION"
_tui_engine_handle_key pager 'k'
check_equal 'pager: 向上动作' 'move-up' "$_TUI_ACTION"

tui_pager '分页' '提示' -- /no/such/file
check_status 'pager: 文件不可读报错' "$TUI_ERROR" "$?"

out=$(_tui_engine_status pager 0 0 1 0 0 2>&1)
[[ "$out" == *'0/0'* ]] || { printf 'FAIL pager: 空内容状态不是 0/0\n' >&2; _failed=$((_failed + 1)); }

tui_begin
tui_begin
check_equal 'core: 嵌套深度' '2' "$_TUI_DEPTH"
tui_end
tui_end
check_equal 'core: 退出嵌套' '0' "$_TUI_DEPTH"

printf '\n通过 %d，失败 %d\n' "$_passed" "$_failed"
((_failed == 0))

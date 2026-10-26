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

UI_MODE=0
_out=$(printf '1\n' | ui_menu '标题' '提示' a A b B)
check_equal 'ui: 单选回退' 'a' "$_out"

_out=$(printf '2\n' | ui_input '标题' '提示' 'z')
check_equal 'ui: 输入回退' '2' "$_out"

_out=$(printf 'y\n' | ui_yesno '标题' '提示'; printf '%s' "$?")
check_equal 'ui: 确认回退' '0' "$_out"

printf '\n通过 %d，失败 %d\n' "$_passed" "$_failed"
((_failed == 0))

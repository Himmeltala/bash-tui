#!/usr/bin/env bash
# 人工演示：菜单、命名菜单、勾选、全选、可选勾选、浏览、分页、输入、确认、暂停，以及标签与勾选记忆。

set -uo pipefail

_dir=${BASH_SOURCE[0]%/*}
[[ "$_dir" == "${BASH_SOURCE[0]}" ]] && _dir='.'
# shellcheck source=/dev/null
source "$_dir/bash-tui.sh"

UI_MODE=1

choice=$(tui_menu 'bash-tui 演示' '选一项' one '第一项' two '第二项')
printf '选择: %s\n' "$choice"

choice=$(tui_menu_named 'bash-tui 演示' '选命令' save '保存当前文件' quit '退出')
printf '命名菜单: %s\n' "$choice"

picked=$(tui_checklist 'bash-tui 演示' '空格勾选' a '甲' OFF b '乙' ON c '丙' OFF)
printf '勾选: %s\n' "$picked"

picked=$(tui_checklist_all 'bash-tui 演示' '全部或逐项勾选' a '甲' ON b '乙' OFF)
printf '全选: %s\n' "$picked"

picked=$(ui_checklist_optional 'bash-tui 演示' '空格勾选，不勾也行' a '甲' OFF b '乙' OFF)
printf '可选勾选: %s\n' "$picked"

choice=$(tui_browse 'bash-tui 演示' '选一行' \
  --hotkey r refresh -- one '主文本一' '说明一' two '主文本二' '说明二')
printf '浏览: %s\n' "$choice"

tui_pager_lines 'bash-tui 演示' '分页查看' -- '第一行' '第二行' '第三行'

tui_confirm '继续' '确定继续吗？' && printf '已确认\n'
name=$(tui_input '输入' '填个名字' '默认值')
printf '输入: %s\n' "$name"

printf '唯一标签: %s\n' "$(ui_unique_tags web /a/web web /b/web | tr '\n' ' ')"

_selection=$(mktemp)
ui_preselect_save "$_selection" b
ui_preselect_load "$_selection"
printf '勾选记忆: %s\n' "${TUI_PRESELECT//$'\n'/ }"
rm -f "$_selection"

ui_pause '演示结束，任意键关闭' || printf '再见\n'

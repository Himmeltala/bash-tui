#!/usr/bin/env bash
# 人工演示：依次走单选、复选、带全部、输入、确认与文本查看。

set -uo pipefail

_dir=${BASH_SOURCE[0]%/*}
[[ "$_dir" == "${BASH_SOURCE[0]}" ]] && _dir='.'
# shellcheck source=/dev/null
source "$_dir/bash-tui.sh"

_tmp=$(mktemp)
printf '第一行\n第二行\n第三行\n' > "$_tmp"

UI_MODE=1
choice=$(ui_menu 'bash-tui 演示' '选一项' one '第一项' two '第二项')
printf '选择: %s\n' "$choice"

picked=$(ui_checklist 'bash-tui 演示' '空格勾选' a '甲' OFF b '乙' ON c '丙' OFF)
printf '勾选: %s\n' "$picked"

ui_textbox '文件内容' "$_tmp"
ui_confirm '继续' '确定继续吗？' && printf '已确认\n'
name=$(ui_input '输入' '填个名字' '默认值')
printf '输入: %s\n' "$name"

rm -f "$_tmp"

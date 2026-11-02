#!/usr/bin/env bash
# 伪终端测试：用 script 提供真实终端，覆盖菜单、勾选、全选、浏览、分页与确认。

set -uo pipefail

_root=${BASH_SOURCE[0]%/*}
[[ "$_root" == "${BASH_SOURCE[0]}" ]] && _root='.'
_root=$(cd "$_root/.." && pwd)

if ! command -v script >/dev/null 2>&1; then
  printf '跳过伪终端测试：未找到 script（util-linux）\n' >&2
  exit 0
fi

_tmp=$(mktemp -d)
trap 'rm -rf "$_tmp"' EXIT
printf '第一行\n第二行\n第三行\n' > "$_tmp/page.txt"

_driver=$_tmp/drive.sh
cat > "$_driver" <<'DRIVER'
#!/usr/bin/env bash
set -uo pipefail
source "$BASH_TUI_SOURCE"

mode=$1
rc=0
case "$mode" in
  menu)
    out=$(tui_menu '菜单标题' '提示' item1 '第一项' item2 '第二项'); rc=$?
    printf '\n==RESULT:%s==\n==RC:%s==\n' "$out" "$rc"
    ;;
  checklist)
    out=$(tui_checklist '勾选标题' '提示' a '甲' OFF b '乙' OFF); rc=$?
    printf '\n==RESULT:%s==\n==RC:%s==\n' "$out" "$rc"
    ;;
  multi_all)
    out=$(tui_checklist_all '全选标题' '提示' a '甲' OFF b '乙' OFF); rc=$?
    printf '%s\n' "$out" | while IFS= read -r line; do
      [[ -n $line ]] && printf '==RESULT:%s==\n' "$line"
    done
    printf '==RC:%s==\n' "$rc"
    ;;
  browse)
    out=$(tui_browse '浏览标题' '提示' -- one '主一' '说明一' two '主二' '说明二'); rc=$?
    printf '\n==RESULT:%s==\n==RC:%s==\n' "$out" "$rc"
    ;;
  pager)
    tui_pager '分页标题' '提示' -- "$PAGER_FILE"; rc=$?
    printf '\n==PAGER-RC:%s==\n' "$rc"
    ;;
  confirm)
    tui_confirm '确认标题' '继续吗'; rc=$?
    printf '\n==CONFIRM-RC:%s==\n' "$rc"
    ;;
esac
exit "$rc"
DRIVER

_passed=0
_failed=0
_pty_out=''
_pty_rc=0

pty_run() {
  local input=$1 mode=$2
  printf '%s' "$input" > "$_tmp/input"
  _pty_out=$(BASH_TUI_SOURCE="$_root/bash-tui.sh" PAGER_FILE="$_tmp/page.txt" \
    timeout 30 script -qec "bash '$_driver' '$mode'" /dev/null < "$_tmp/input" 2>&1)
  _pty_rc=$?
}

check_rc() {
  local name=$1 expected=$2
  if ((_pty_rc == expected)); then
    _passed=$((_passed + 1))
  else
    printf 'FAIL %s\n  expected rc: %s\n  actual rc:   %s\n' "$name" "$expected" "$_pty_rc"
    _failed=$((_failed + 1))
  fi
}

check_contains() {
  local name=$1 needle=$2
  if [[ $_pty_out == *"$needle"* ]]; then
    _passed=$((_passed + 1))
  else
    printf 'FAIL %s\n  缺少标记: %s\n' "$name" "$needle"
    _failed=$((_failed + 1))
  fi
}

pty_run $'\n' menu
check_rc 'pty: 菜单回车退出码' 0
check_contains 'pty: 菜单选中项' '==RESULT:item1=='
check_contains 'pty: 菜单绘制标题' '菜单标题'

pty_run $' \n' checklist
check_rc 'pty: 勾选确认退出码' 0
check_contains 'pty: 勾选选中项' '==RESULT:a=='

pty_run $' \n' multi_all
check_rc 'pty: 全选确认退出码' 0
check_contains 'pty: 全选包含第一项' '==RESULT:a=='
check_contains 'pty: 全选包含第二项' '==RESULT:b=='

pty_run $'\n' browse
check_rc 'pty: 浏览回车退出码' 0
check_contains 'pty: 浏览选中项' '==RESULT:one=='

pty_run $'\n' pager
check_rc 'pty: 分页回车关闭退出码' 0
check_contains 'pty: 分页关闭返回码' '==PAGER-RC:0=='
check_contains 'pty: 分页绘制标题' '分页标题'

pty_run 'y' confirm
check_rc 'pty: 确认退出码' 0
check_contains 'pty: 确认结果' '==CONFIRM-RC:0=='

pty_run 'b' menu
check_rc 'pty: 菜单返回退出码' 4
check_contains 'pty: 菜单返回码可见' '==RC:4=='

printf '\n通过 %d，失败 %d\n' "$_passed" "$_failed"
((_failed == 0))

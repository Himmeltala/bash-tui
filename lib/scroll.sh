# 把光标与窗口偏移收敛到合法范围，结果写 _TUI_CURSOR 与 _TUI_OFFSET。

_tui_clamp_window() {
  local cursor=$1 offset=$2 window=$3 total=$4
  ((window > total)) && window=$total
  ((window < 1)) && window=1
  ((total < 1)) && total=1
  ((cursor < 0)) && cursor=0
  ((cursor >= total)) && cursor=$((total - 1))
  if ((_TUI_PAGE_ALIGN)); then
    offset=$((cursor / window * window))
    _TUI_PAGE_ALIGN=0
  fi
  ((offset < 0)) && offset=0
  ((cursor < offset)) && offset=$cursor
  ((cursor >= offset + window)) && offset=$((cursor - window + 1))
  local floor=$((total - window))
  ((floor < 0)) && floor=0
  ((offset > floor)) && offset=$floor
  _TUI_CURSOR=$cursor
  _TUI_OFFSET=$offset
  return 0
}

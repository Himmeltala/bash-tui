#!/usr/bin/env bash
# bash-tui 入口：版本检查后按依赖顺序加载模块。
# 被 source 时只加载；直接执行时打印版本与用法。

if [[ -n ${_BASH_TUI_LOADED:-} ]]; then
  if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    exit 0
  fi
  return 0
fi
_BASH_TUI_LOADED=1

BASH_TUI_VERSION='0.2.0'

if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 2))); then
  printf 'bash-tui: 需要 bash 4.2 及以上，当前 %s\n' "$BASH_VERSION" >&2
  if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    return 1
  fi
  exit 1
fi

_bash_tui_dir=${BASH_SOURCE[0]%/*}
[[ "$_bash_tui_dir" == "${BASH_SOURCE[0]}" ]] && _bash_tui_dir='.'

for _bash_tui_module in core render key scroll select dialog view fallback ui; do
  # shellcheck source=/dev/null
  if ! source "$_bash_tui_dir/lib/$_bash_tui_module.sh"; then
    printf 'bash-tui: 加载模块 %s 失败\n' "$_bash_tui_module" >&2
    unset _bash_tui_module
    if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
      return 1
    fi
    exit 1
  fi
done
unset _bash_tui_module

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf 'bash-tui %s\n' "$BASH_TUI_VERSION"
  printf '用法: source %s/bash-tui.sh\n' "$_bash_tui_dir"
fi

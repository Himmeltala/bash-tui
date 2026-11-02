# bash-tui

bash 终端界面组件库，包含自绘菜单、勾选、浏览、分页、输入与确认。

要求 bash 4.2 及以上。

## 使用

```bash
source /path/to/bash-tui/bash-tui.sh
```

画面写 stderr，结果写 stdout。

## 接口

| 函数 | 说明 |
| --- | --- |
| `tui_menu` | 单选菜单 |
| `tui_checklist` | 多选勾选 |
| `tui_checklist_all` | 带“全部”开关的多选 |
| `tui_browse` | 自定义主文本与说明文本的浏览列表，支持热键 |
| `tui_pager` | 分页查看文件，支持热键 |
| `tui_pager_lines` | 分页查看行数组，支持热键 |
| `tui_input` | 单行输入 |
| `tui_confirm` | 是否确认 |
| `tui_wait_key` | 原地等待一个按键，不切换界面 |
| `ui_*` | 对应的无终端回退包装 |

```bash
tui_menu '标题' '提示' '标签' '文本' ...
tui_checklist '标题' '提示' '标签' '文本' ON ...
tui_checklist_all '标题' '提示' '标签' '文本' OFF ...
tui_browse '标题' '提示' [--hotkey 键 动作 [显示标签]]... -- '标签' '主文本' '说明文本' ...
tui_pager '标题' '提示' [--hotkey 键 动作 [显示标签]]... -- '文件'
tui_pager_lines '标题' '提示' [--hotkey 键 动作 [显示标签]]... -- '行' ...
tui_input '标题' '提示' ['默认值']
tui_confirm '标题' '提示'
tui_wait_key '提示'
```

菜单、浏览与勾选把选中项的标签写到 stdout，勾选每行一个。

## 按键

列表视图（菜单、勾选、浏览）：↑↓ 或 k/j 移动，回车确认，`[` `]` 翻页；勾选视图空格勾选；`←`、`ESC`、`b`、`B` 与退格返回上一步，`q` 取消。

分页视图：↑↓ 或 k/j 滚动，空格或 `[` `]` 翻页；回车、`q`、`ESC`、`←` 正常关闭。

## 热键

`--hotkey <键> <动作> [显示标签]` 可重复，放在 `--` 与条目之前。单字符键不区分大小写，命名键（如 `UP`、`LEFT`、`ENTER`）按名匹配。按下后把 `@hotkey:<动作>` 写到 stdout 并返回 `TUI_OK`。动作名不能以 `@hotkey:` 开头。显示标签只用于工具条提示，省略时显示动作名。

## 返回码

| 常量 | 值 | 含义 |
| --- | --- | --- |
| `TUI_OK` | 0 | 成功 |
| `TUI_CANCEL` | 1 | 取消 |
| `TUI_EMPTY` | 2 | 没有选中项 |
| `TUI_ERROR` | 3 | 参数或文件错误 |
| `TUI_BACK` | 4 | 返回上一步 |

列表视图里 `←`、`ESC`、`b`、`B` 与退格返回 `TUI_BACK`，`q` 返回 `TUI_CANCEL`。分页视图里 `q`、`ESC`、`←` 与回车都正常关闭并返回 `TUI_OK`。

`tui_confirm` 以 0/1 表示确认与取消。

## 预选

`TUI_PRESELECT` 按标签预勾选 `tui_checklist` 与 `tui_checklist_all` 的条目，多个标签以换行分隔。

## 配置

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `UI_MODE` | `0` | 非 0 时 `ui_*` 走终端界面，否则走编号输入 |
| `TUI_PRESELECT` | 空 | 预选标签，换行分隔 |
| `TUI_LABEL_ALL` | `全部` | 全选行主文本 |
| `TUI_LABEL_ALL_DESC` | `选中全部模块` | 全选行说明 |
| `TUI_MIN_COLS` | `40` | 最小宽度 |
| `TUI_ESC_TIMEOUT` | `0.05` | 转义序列超时 |
| `TUI_PAGE_SIZE` | 空 | 列表视图可见行数上限；空、`0` 或非正整数表示按终端高度铺满 |

## 验证

```bash
bash -n bash-tui.sh lib/*.sh
bash test/run.sh
bash test/pty.sh
bash demo.sh
```

`test/pty.sh` 依赖 util-linux 的 `script`；没有时打印跳过提示并以 0 退出。

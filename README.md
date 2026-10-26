# bash-tui

bash 终端界面组件库，包含自绘菜单、复选、输入、确认与分页文本查看。

要求 bash 4.2 及以上。

## 使用

```bash
source /path/to/bash-tui/bash-tui.sh
```

画面写 stderr，结果写 stdout。

## 按键

↑↓ 移动，空格勾选，回车确认，q 取消，← 返回。列表行数超过 `TUI_PAGE_SIZE` 时用 `[` `]` 上下翻页。

## 接口

| 函数 | 说明 |
| --- | --- |
| `tui_select` | 列表选择，模式为 `menu`、`checklist`、`all` |
| `tui_input` | 单行输入 |
| `tui_confirm` | 是否确认 |
| `tui_textbox` | 分页查看文本文件 |
| `ui_menu`、`ui_checklist`、`ui_checklist_all`、`ui_input`、`ui_yesno`、`ui_textbox` | 带无终端回退的包装 |

## 返回码

| 常量 | 值 | 含义 |
| --- | --- | --- |
| `TUI_OK` | 0 | 成功 |
| `TUI_CANCEL` | 1 | 取消 |
| `TUI_EMPTY` | 2 | 没有选中项 |
| `TUI_ERROR` | 3 | 参数或文件错误 |
| `TUI_BACK` | 4 | 返回上一步 |

## 配置

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `TUI_PRESELECT` | 空 | 预选标签，换行分隔 |
| `TUI_LABEL_ALL` | `全部` | 全选行主文本 |
| `TUI_LABEL_ALL_DESC` | `选中全部模块` | 全选行说明 |
| `TUI_MIN_COLS` | `40` | 最小宽度 |
| `TUI_ESC_TIMEOUT` | `0.05` | 转义序列超时 |
| `TUI_PAGE_SIZE` | `0` | 列表一屏最多显示多少行，0 表示按终端高度铺满；超过后用 `[` `]` 翻页 |

## 验证

```bash
bash -n bash-tui.sh lib/*.sh
bash test/run.sh
bash demo.sh
```

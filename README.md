# bash-tui

bash 的终端界面组件库：自绘菜单、勾选、浏览、分页、输入与确认，探不到终端时自动退回编号输入。

## 安装

### 兼容性

- bash 4.2 及以上。用到关联数组、`mapfile` 与 `read -e -i`，这几个是硬要求。
- Linux 与 macOS 的终端都能用。macOS 自带的 bash 是 3.2，版本不够，先 `brew install bash`，再用新装的 bash 运行脚本。
- 终端尺寸优先用 `tput` 查，没有 `tput` 时读 `LINES`、`COLUMNS`，再退回 24 行 × 100 列。
- 标签去重的极端情况用 `md5sum` 兜底，多数环境自带，缺了也不影响常规使用。
- 设置 `NO_COLOR` 或把 `TERM` 设为 `dumb` 可以关掉颜色。

### 安装方式

bash-tui 是纯 bash 库，没有构建步骤，放好源码、在脚本里 source 入口就行：

```bash
git clone https://github.com/Himmeltala/bash-tui.git
source /path/to/bash-tui/bash-tui.sh
```

同一台机器上多个脚本要用，可以放到固定目录（例如 `~/.local/lib/bash-tui`），各脚本 source 那个路径。

装了 [bash-scripts](https://github.com/Himmeltala/bash-scripts) 的，bash-tui 由它的 `install.sh` 按 `bash-tui.ref` 拉取到 `vendor/bash-tui`，各个工具自动找到，不用再单独装。

## 快速开始

最小的例子：探测终端，弹出菜单，拿到选中的标签。

```bash
source /path/to/bash-tui/bash-tui.sh

ui_detect
choice=$(ui_menu '演示' '选一个操作' save '保存当前文件' quit '退出') || exit 0
printf '选了 %s\n' "$choice"
```

- 画面写 stderr，结果写 stdout，所以 `choice=$(...)` 能直接接住选中的标签。
- `ui_detect` 只判断一次：三个标准流都连着终端才画界面，否则同一段代码退回编号输入，照样能跑。
- 取消返回 `TUI_CANCEL`，接一句 `|| exit 0` 就够了。

仓库里的 `demo.sh` 把主要组件串成一个可点的演示，`bash demo.sh` 即可。

## 组件总览

组件分两层：`ui_*` 是包装层，自动判断有没有终端，没有终端退回编号输入或普通输出；`tui_*` 是终端层，只在界面里用，不做降级。

| 组件 | 接口 | 用途 |
| --- | --- | --- |
| 终端探测 | `ui_detect` `ui_available` | 判断当前能不能画界面 |
| 菜单 | `ui_menu` `tui_menu` | 单选一项，返回标签 |
| 命名菜单 | `ui_menu_named` | 标签就是命令名，说明作小字 |
| 条目文本 | `ui_item_text` | 拼「名字 + 说明」，两种模式都不重复 |
| 勾选 | `ui_checklist` `tui_checklist` | 多选，返回选中的标签 |
| 全选勾选 | `ui_checklist_all` | 多选，带「全部」总开关 |
| 可选勾选 | `ui_checklist_optional` | 多选，没勾也算成功 |
| 浏览列表 | `ui_browse` `tui_browse` | 带说明文本与热键的列表 |
| 分页 | `ui_pager` `ui_pager_lines` | 翻页看文件或行数组 |
| 输入 | `ui_input` `tui_input` | 单行输入，可带默认值 |
| 确认 | `ui_yesno` `tui_confirm` | 是或否 |
| 等键 | `ui_wait_key` `tui_wait_key` | 原地等一个按键，不切屏 |
| 暂停 | `ui_pause` | 看完结果停一下，按 q 退出 |
| 标签去重 | `ui_unique_tags` | 同名条目加路径尾巴，标签保持唯一 |
| 勾选记忆 | `ui_preselect_load` `ui_preselect_save` | 记住上次勾了什么 |

每个组件的用法、变体与参数见 [组件文档](docs/components.md)。

## 验证

```bash
bash -n bash-tui.sh lib/*.sh
bash test/run.sh      # 无终端自测：纯计算、回退层与参数校验
bash test/pty.sh      # 伪终端测试：界面绘制与按键
bash demo.sh          # 手动点一遍
```

`test/pty.sh` 依赖 util-linux 的 `script`，没有时打印跳过提示并以 0 退出。

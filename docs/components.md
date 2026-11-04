# 组件

bash-tui 的组件分两层：

- `ui_*` 包装层：先看有没有终端。有终端画界面，没有终端退回编号输入或普通输出，调用方不必自己判断。
- `tui_*` 终端层：只画界面，不做降级。需要在界面里嵌套调用时用这一层。

几条全局约定，后文不再重复：

- **画面写 stderr，结果写 stdout**。所以 `chosen=$(ui_menu ...)` 这样的命令替换拿到的只有结果。
- **返回码**：`TUI_OK` 为 0，`TUI_CANCEL` 为 1，`TUI_EMPTY` 为 2，`TUI_ERROR` 为 3，`TUI_BACK` 为 4。`ui_*` 把 `tui_*` 的返回码原样透传。
- **条目文本**：一个条目的文本里带制表符时，前面是主文本，后面是小字说明；不带制表符就整段当主文本。
- **按键**（列表视图）：↑↓ 或 `k`、`j` 移动，回车确认，空格勾选，`[` `]` 翻页，`q` 取消，`←`、`ESC`、`b`、`B` 与退格返回上一步。
- **环境变量**：`TUI_PRESELECT` 预勾选的标签（换行分隔），`TUI_LABEL_ALL` 与 `TUI_LABEL_ALL_DESC` 是「全部」行的两段文字，`TUI_MIN_COLS` 最小列数（默认 40），`TUI_ESC_TIMEOUT` 转义序列超时（默认 0.05 秒），`TUI_PAGE_SIZE` 列表可见行数上限（空或 0 表示按终端高度铺满）。

---

## 终端探测

判断当前能不能画界面。整个程序只在启动时调用一次 `ui_detect`，之后一律读 `UI_MODE`。

### 基本用法

```bash
source /path/to/bash-tui/bash-tui.sh

ui_detect
if ui_available; then
  printf '能画界面\n'
else
  printf '退回编号输入\n'
fi
```

`ui_detect` 看三个标准流：`stdin`、`stdout`、`stderr` 都连着终端才把 `UI_MODE` 置 1，否则置 0。判断必须在命令替换之外做，因为替换里的 stdout 是管道，`[[ -t 1 ]]` 永远为假。

### 变体用法

#### 在管道里验证回退路径

测试或脚本里想强制走编号输入，直接赋值，不要调用 `ui_detect`：

```bash
UI_MODE=0
printf '1\n' | ui_menu '标题' '提示' a 'A' b 'B'
```

#### 强制走界面

伪终端测试里可以直接置 1：

```bash
UI_MODE=1
ui_menu '标题' '提示' a 'A'
```

### 参数总览

| 函数 | 参数 | 说明 |
| --- | --- | --- |
| `ui_detect` | 无 | 写全局 `UI_MODE`，恒返回 0 |
| `ui_available` | 无 | 返回 0 表示能画界面，1 表示不能 |

---

## 菜单

单选一项，返回选中项的标签。

### 基本用法

```bash
choice=$(ui_menu '部署' '选一个环境' prod '生产' stage '预发' quit '退出') || return 0
printf '选了 %s\n' "$choice"
```

参数是成对的「标签 + 文本」：界面里显示文本，标签只用来回传结果；编号回退里标签进第一列，文本作为说明。

### 变体用法

#### 说明文本分主次

文本里带制表符时，前面是主文本，后面是灰色小字：

```bash
ui_menu '文件' '选一个操作' save $'保存\tCtrl+S' quit $'退出\tq'
```

#### 区分取消与返回上一步

`q` 返回 `TUI_CANCEL`（1），`ESC`、`←`、`b`、`B`、退格返回 `TUI_BACK`（4）。多级菜单靠这个区分：

```bash
choice=$(ui_menu '标题' '提示' a 'A' back '返回') || {
  case $? in
    4) return 0 ;;   # 回上一级
    *) exit 0 ;;     # 取消，整个退出
  esac
}
```

#### 只在终端里调用

已经在界面流程里，不需要再判断终端时用 `tui_menu`，参数与返回码和 `ui_menu` 一样：

```bash
tui_menu '标题' '提示' a 'A'
```

### 参数总览

| 参数 | 说明 |
| --- | --- |
| `title` | 标题，画在顶部 |
| `prompt` | 提示行，可为空字符串 |
| `标签 文本` | 成对出现，至少一对；空列表或落单时报 `TUI_ERROR` |
| 返回 | 0 且 stdout 输出选中标签；1 取消；4 返回上一步；3 参数错 |

---

## 命名菜单

标签本身就是命令名，界面上把命令名当主文本、说明当小字。适合「选一个命令」这类菜单。

### 基本用法

```bash
action=$(ui_menu_named 'mvnx' '选命令' \
  run '启动应用' \
  build '构建' \
  quit '退出') || return 0

case $action in
  run | build) do_action "$action" ;;
  quit) return 0 ;;
esac
```

界面里主文本写 `run`，小字写「启动应用」；编号回退里第一列就是 `run`，第二列是说明，名字不会重复出现。

### 变体用法

#### 标签与显示名不同

命名菜单假设「标签即名字」。如果显示名和标签不一样（比如给同名目标加路径尾巴），用 `ui_browse` 或普通 `ui_menu`，别用命名菜单。

#### 在勾选里保持名字可见

勾选项的标签是数据本身（会话 id、包名）时，用 `ui_item_text` 拼文本，见 [条目文本](#条目文本)。

### 参数总览

| 参数 | 说明 |
| --- | --- |
| `title` | 标题 |
| `prompt` | 提示行 |
| `名字 说明` | 成对出现，至少一对；落单时报 `TUI_ERROR` |
| 返回 | 同 `ui_menu` |

---

## 条目文本

给勾选项拼「名字 + 说明」，让名字在界面和编号回退里都只出现一次。

### 基本用法

```bash
local -a items=()
ui_item_text 'session-01' '昨天的会话'
items+=('session-01' "$UI_ITEM_TEXT" OFF)
```

结果写在全局 `UI_ITEM_TEXT` 里，不输出到 stdout。界面模式下是 `名字<TAB>说明`，编号回退下只有说明——因为编号列表的第一列已经画了标签，再画一遍名字就重复了。

### 变体用法

#### 给菜单用

`ui_menu_named` 内部就是逐个调用它拼条目文本。自己拼菜单时也可以这么用：

```bash
ui_item_text 'run' '启动应用'
ui_menu 'mvnx' '选命令' run "$UI_ITEM_TEXT"
```

#### 不要用命令替换

`ui_item_text` 靠全局变量回传，写成 `text=$(ui_item_text ...)` 会落在子 shell 里，父 shell 读不到。直接当语句调用。

### 参数总览

| 参数 | 说明 |
| --- | --- |
| `name` | 名字，通常与标签相同 |
| `extra` | 说明文本 |
| 结果 | 全局 `UI_ITEM_TEXT`；函数恒返回 0 |

---

## 勾选

多选一组条目，返回选中的标签，每行一个。

### 基本用法

```bash
picked=$(ui_checklist '清理' '空格勾选，回车确认' \
  cache '缓存' ON \
  log '日志' OFF) || return 0

mapfile -t ids <<< "$picked"
printf '勾了 %d 项\n' "${#ids[@]}"
```

参数是成三元的「标签 + 文本 + 状态」，状态只能是 `ON` 或 `OFF`。界面里空格勾选、回车确认；编号回退里输入编号，空格分隔。

### 变体用法

#### 预勾选

`TUI_PRESELECT` 按标签预勾选，多个标签用换行分隔：

```bash
TUI_PRESELECT=$'cache\nlog'
picked=$(ui_checklist '清理' '空格勾选' cache '缓存' OFF log '日志' OFF) || return 0
```

#### 说明文本分主次

与菜单一样支持制表符，前面是主文本，后面是小字：

```bash
ui_checklist '清理' '空格勾选' cache $'缓存\t已用 1.2G' OFF
```

#### 一个都没勾

界面里直接回车、编号输入里空回车，都返回 `TUI_EMPTY`（2），stdout 为空。想当成「跳过」处理，用 [可选勾选](#可选勾选)。

#### 返回上一步

`←`、`ESC`、`b`、`B`、退格返回 `TUI_BACK`（4），调用方据此回到上一级菜单。

### 参数总览

| 参数 | 说明 |
| --- | --- |
| `title` | 标题 |
| `prompt` | 提示行 |
| `标签 文本 状态` | 成三元出现，至少一组；状态非 `ON`/`OFF` 报 `TUI_ERROR` |
| 返回 | 0 且输出选中标签（每行一个）；1 取消；2 一项没勾；4 返回上一步；3 参数错 |

---

## 全选勾选

与勾选一样，但列表顶部多一行「全部」，可以一次勾上或一次取消。

### 基本用法

```bash
picked=$(ui_checklist_all '构建' '空格勾选，0 全选' \
  a '模块 A' OFF \
  b '模块 B' ON) || return 0
```

界面里「全部」是独立一行：所有条目都勾上时按下它的动作是全部取消，否则全部勾上。编号回退里输入 `0` 得到全部标签。

### 变体用法

#### 改「全部」行的文案

```bash
TUI_LABEL_ALL='全部模块'
TUI_LABEL_ALL_DESC='选中全部模块'
ui_checklist_all '构建' '空格勾选' a '模块 A' OFF
```

#### 全部取消后回车

同样返回 `TUI_EMPTY`（2）。要当成功处理，按 [可选勾选](#可选勾选) 里的写法自己折一下，`ui_checklist_optional` 只包装了普通勾选。

### 参数总览

| 参数 | 说明 |
| --- | --- |
| `title` | 标题 |
| `prompt` | 提示行 |
| `标签 文本 状态` | 成三元出现，至少一组 |
| 返回 | 同 [勾选](#勾选)；编号回退里输入 `0` 时输出全部标签 |

---

## 可选勾选

勾选，但「一个都没勾」也算成功。适合「勾了就处理、不勾就跳过」的场合。

### 基本用法

```bash
picked=$(ui_checklist_optional '清理' '空格勾选，回车确认' \
  cache '缓存' OFF \
  log '日志' OFF) || return 0

if [[ -z $picked ]]; then
  printf '没勾，跳过\n'
  return 0
fi
process "$picked"
```

参数与返回码和 [勾选](#勾选) 一致，只是把 `TUI_EMPTY` 折成 `TUI_OK`，stdout 为空。

### 变体用法

#### 与全选勾选组合

`ui_checklist_optional` 只包装了 `ui_checklist`。要「全部行 + 空选当成功」，先拿 `ui_checklist_all` 的结果再自己折一下：

```bash
picked=$(ui_checklist_all '构建' '空格勾选' a '模块 A' OFF)
rc=$?
((rc == 2)) && picked=''
((rc == 0 || rc == 2)) || return "$rc"
```

#### 取消与返回照旧透传

`q` 仍是 `TUI_CANCEL`（1），`ESC` 等仍是 `TUI_BACK`（4），不会被折成成功。

### 参数总览

| 参数 | 说明 |
| --- | --- |
| 全部 | 同 [勾选](#勾选) |
| 返回 | 0（含一项没勾）；1 取消；4 返回上一步；3 参数错 |

---

## 浏览列表

带主文本、说明文本与热键的列表，用来浏览数据而不是选命令。

### 基本用法

```bash
choice=$(ui_browse '端口列表' '回车查看，q 取消' \
  -- p:80 '80/TCP' 'nginx，pid 1200' \
     p:8080 '8080/TCP' 'java，pid 2400') || return 0

case $choice in
  p:*) printf '选了端口 %s\n' "${choice#p:}" ;;
esac
```

`--` 之后是三元组「标签 + 主文本 + 说明文本」。界面里主文本一行、说明文本一行；编号回退里主文本进第一列。

### 变体用法

#### 热键

热键放在 `--` 之前，可重复：`--hotkey 键 动作 [显示标签]`。按下后不返回标签，而是返回 `@hotkey:<动作>`：

```bash
choice=$(ui_browse '端口列表' 'r 刷新，u 切换 UDP' \
  --hotkey r refresh 刷新 --hotkey u udp UDP \
  -- p:80 '80/TCP' 'nginx') || return 0

case $choice in
  '@hotkey:udp') UDP=$((1 - UDP)) ;;
  '@hotkey:refresh') ;;
  p:*) detail "${choice#p:}" ;;
esac
```

工具的底部提示条会自动列出已经绑定的热键。编号回退里热键不生效。

#### 只读浏览

不需要选中动作时，忽略返回值，用 `q` 或返回键退出。

### 参数总览

| 参数 | 说明 |
| --- | --- |
| `title` | 标题 |
| `prompt` | 提示行 |
| `--hotkey 键 动作 [标签]` | 可重复，必须写在 `--` 之前 |
| `--` | 分隔符，之后是条目 |
| `标签 主文本 说明` | 成三元出现；不是三的倍数报 `TUI_ERROR` |
| 返回 | 0 且输出标签或 `@hotkey:动作`；1 取消；4 返回；3 参数或热键写错 |

---

## 分页

翻页查看一个文件或一组文本行，不占满整个界面。

### 基本用法

```bash
ui_pager '构建日志' '↑↓ 滚动，q 关闭' -- /tmp/build.log
```

返回 0 表示正常关闭。文件不存在或读不了报 `TUI_ERROR`。

### 变体用法

#### 看行数组

内容已经在内存里时用 `ui_pager_lines`，不必先落盘：

```bash
ui_pager_lines '会话详情' '↑↓ 滚动，q 返回' -- "${INFO_LINES[@]}"
```

#### 分页里的热键

与浏览列表一样支持 `--hotkey`，按下返回 `@hotkey:<动作>`：

```bash
action=$(ui_pager_lines '端口 80' 'q 返回' \
  --hotkey k kill 结束 --hotkey p dir 目录 \
  -- "${INFO_LINES[@]}") || return 0
```

#### 没有终端时

回退模式下 `ui_pager` 直接把文件内容打到 stdout（等价 `cat`），`ui_pager_lines` 逐行打印，热键不参与。

### 参数总览

| 参数 | 说明 |
| --- | --- |
| `title` | 标题 |
| `prompt` | 提示行 |
| `--hotkey 键 动作 [标签]` | 可重复，必须写在 `--` 之前 |
| `--` | 分隔符 |
| 文件 | `ui_pager` 只接受一个文件路径；`ui_pager_lines` 接受若干行 |
| 返回 | 0 关闭（`q`、`ESC`、回车都算关闭）；3 参数错或文件读不了 |

---

## 输入

单行输入，可以带默认值。

### 基本用法

```bash
name=$(ui_input '新建' '输入名称' '未命名') || return 0
printf '名称是 %s\n' "$name"
```

界面里带行编辑（方向键、退格可用），默认值预先填好；编号回退里把默认值写在方括号里，直接回车就是默认值。

### 变体用法

#### 取消

`Ctrl+C` 或读到文件尾返回 `TUI_CANCEL`（1）。用 `|| return 0` 收场即可。

#### 留空表示不限

提示里写清楚，代码里把空串当默认值处理：

```bash
days=$(ui_input '统计范围' '留空表示全部' '') || return 0
[[ -n $days ]] || days=0
```

### 参数总览

| 参数 | 说明 |
| --- | --- |
| `title` | 标题 |
| `prompt` | 提示行 |
| `default` | 可选，默认值，省略为空 |
| 返回 | 0 且 stdout 输出一行文本；1 取消；3 参数错 |

---

## 确认

是或否，用于删除、覆盖、归档这类不可逆操作。

### 基本用法

```bash
if ui_yesno '删除会话' '删除后无法恢复，确定继续？'; then
  delete_session "$id"
fi
```

界面里按 `y` 或 `Y` 确认，其余按键都算取消；编号回退里输入 `y`、`Y`、`yes` 确认，其他算取消。

### 变体用法

#### 默认跳过确认

`--yes`、`DRY_RUN` 这类开关的判断放在调用之前，别塞进组件：

```bash
if ((!ASSUME_YES)) && ! ui_yesno '清理' '确定清理？'; then
  return 0
fi
```

#### 只在终端里问

`tui_confirm` 不降级，返回 0 表示确认。

### 参数总览

| 函数 | 参数 | 返回 |
| --- | --- | --- |
| `ui_yesno` | `title` `prompt` | 0 确认；1 取消或读到文件尾 |
| `tui_confirm` | `title` `prompt` | 0 按了 `y`/`Y`；1 其他 |

---

## 等键

原地等一个按键，不切换界面，也不清屏。适合报表打完停一下。

### 基本用法

```bash
key=$(ui_wait_key '按任意键继续') || return 0
if [[ $key == q ]]; then
  return 1
fi
```

提示写在 stderr，按下的键从 stdout 返回。没有终端时读一行输入并回显，方便管道里驱动。

### 变体用法

#### 看完就回菜单

需要「任意键回菜单、q 退出」这套固定语义时，用 [暂停](#暂停) 更省事。

#### 等一个特定键

自己比较返回的键名，命名键是 `UP`、`DOWN`、`LEFT`、`RIGHT`、`ENTER`、`ESC`、`BACKSPACE` 这类大写名字。

### 参数总览

| 函数 | 参数 | 返回 |
| --- | --- | --- |
| `ui_wait_key` | `prompt` | 0 且输出键名；1 读到文件尾 |
| `tui_wait_key` | `prompt` | 同上，但不降级 |

---

## 暂停

等一个按键后继续，按 `q` 表示退出。给「看完结果停一下」的场景用。

### 基本用法

```bash
ui_pause || return 0
```

提示默认是「按回车返回」。按 `q` 或 `Q` 返回 1，其余按键返回 0。

### 变体用法

#### 自定义提示

```bash
ui_pause '任意键回到菜单，q 退出' || return 0
```

#### 没有终端时

直接返回 0，并且不读 stdin。这样管道里后面的菜单按键不会被吃掉：

```bash
UI_MODE=0
printf 'q\n' | bash -c 'source ./bash-tui.sh; ui_pause; IFS= read -r x; printf "%s" "$x"'   # 输出 q
```

### 参数总览

| 参数 | 说明 |
| --- | --- |
| `prompt` | 可选，默认「按回车返回」 |
| 返回 | 0 继续；1 按了 `q`；没有终端时恒为 0 |

---

## 标签去重

同名条目在界面里分不清，勾选记录也会互相覆盖。这个组件给同名 id 加上展示路径的尾巴，生成唯一标签。

### 基本用法

```bash
mapfile -t tags < <(ui_unique_tags web /work/a/web web /work/b/web api /work/a/api)

# tags = (web@a/web web@b/web api)
```

参数是成对的「id + 展示路径」，输出的标签与参数同序，每行一个。不重名的 id 原样返回；重名的按路径尾巴加长，直到组内两两可分。

### 变体用法

#### 尾巴段数逐段加长

先试最后一段，组内撞了就试两段，最多 20 段。段数按组统一，同批记录不会有的两段有的三段。

#### 尾巴等于 id 时继续加长

两个 `app` 重名，展示路径是 `/w/app` 与 `/w/b/appx`：最后一段是 `app` 与 `appx`，本来不撞，但 `app` 与 id 一字不差，等于没加，于是取两段，得到 `app@w/app` 与 `app@b/appx`。

#### 极端情况补哈希

20 段仍分不开（展示路径完全一致）时，在标签后补一段展示路径的 md5 前四位。标签会写进勾选记忆文件，所以别在标签里放换行符。

### 参数总览

| 参数 | 说明 |
| --- | --- |
| `id 展示路径` | 成对出现，至少一对；落单报 `TUI_ERROR` |
| 返回 | 0 且输出标签（每行一个）；3 参数错 |
| 依赖 | 兜底哈希用 `md5sum`，缺失时只影响极端重名的场景 |

---

## 勾选记忆

把上次勾选的标签存进文件，下次打开同一张勾选表时回填。

### 基本用法

```bash
selection="$CACHE_DIR/modules.selected"
local -a picked=()
local picked_out=''

ui_preselect_load "$selection"
picked_out=$(ui_checklist '模块' '空格勾选，回车确认' "${items[@]}") || return 0
mapfile -t picked <<< "$picked_out"
ui_preselect_save "$selection" "${picked[@]}"
```

`ui_preselect_load` 把文件内容读进 `TUI_PRESELECT`；`ui_preselect_save` 用这次的标签覆盖文件，一行一个。用 `mapfile` 收结果，标签里带空格也不会被拆开。

### 变体用法

#### 文件还不存在

`ui_preselect_load` 会把 `TUI_PRESELECT` 清空，等同于没有预选；`ui_preselect_save` 会先建目录再写文件。

#### 手动指定预选

不读文件时直接给 `TUI_PRESELECT` 赋值即可：

```bash
TUI_PRESELECT=$'cache\nlog'
ui_checklist '清理' '空格勾选' cache '缓存' OFF log '日志' OFF
```

### 参数总览

| 函数 | 参数 | 说明 |
| --- | --- | --- |
| `ui_preselect_load` | `文件` | 读进 `TUI_PRESELECT`；文件不在时置空 |
| `ui_preselect_save` | `文件 标签...` | 覆盖写入，一行一个；目录不存在时建；缺文件路径报 `TUI_ERROR` |

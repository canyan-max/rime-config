> **这是个人的 Rime 配置备份仓库，不是雾凇拼音（rime-ice）官方仓库。**
> 内容主体取自 [iDvel/rime-ice](https://github.com/iDvel/rime-ice)，遵循 GPL-3.0（见 [LICENSE](./LICENSE)）；
> 另含本人的定制补丁、一个释义滤镜 Lua 脚本和 CC-CEDICT 词典；上游的方案说明与词库文档见 [iDvel/rime-ice](https://github.com/iDvel/rime-ice)。

## 个人仓库说明

### 这是什么

本机在用的 Rime 用户目录快照（Windows + 小狼毫 Weasel 0.17.4 便携版），用来在新机器上还原成同一套输入体验。

### 仓库独有、上游没有的文件

| 文件 | 作用 |
| --- | --- |
| `default.custom.yaml` | 标点全部半角化，覆盖 `punctuator` 的 `half_shape` / `full_shape` 两套映射 |
| `rime_ice.custom.yaml` | 默认 ASCII 输出、关闭 Emoji 候选、默认半角标点，并接入词典释义滤镜 |
| `weasel.custom.yaml` | VS Code Dark+ 黑底配色、竖向候选、字号与行高压缩 |
| `lua/dict_comment_filter.lua` | 候选旁显示 CC-CEDICT 中英释义的滤镜（<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>E</kbd> 开关） |
| `opencc/cedict.json`、`cedict.txt`、`cedict.ocd2` | 上述滤镜用的 CC-CEDICT 词典。`cedict.json` 的 dict 类型是 `ocd2`，所以 `.ocd2` 必须一起提交 |
| `custom_phrase.txt` | 自定义短语 |

### 在新机器上还原（Windows + 小狼毫便携版）

1. 解压/安装**同版本**小狼毫（0.17.4）便携版，例如 `D:\Soft\21_rimer_app\weasel-0.17.4`。
2. 指定用户目录。便携版就是靠这个注册表项找到用户目录的，不设则使用默认的 `%APPDATA%\Rime`：
   ```bat
   reg add "HKCU\SOFTWARE\Rime\Weasel" /v RimeUserDir /t REG_SZ /d "D:\Soft\21_rimer_app\my_rime_user" /f
   ```
3. 把仓库克隆到该目录（目录必须是空的）：
   ```bash
   git clone https://github.com/canyan-max/rime-config.git "D:/Soft/21_rimer_app/my_rime_user"
   ```
   git 不读取 Windows 的系统代理设置。需要走代理时，在本仓库内执行（端口换成你自己的）：
   ```bash
   git config http.proxy http://127.0.0.1:7897
   ```
4. 推荐配置 clean 过滤器，这样 Weasel 重写补丁文件头部时不会污染 `git status`：
   ```bash
   git config filter.rimecustom.clean "sed -e '/^customization:/,/^[^[:space:]]/{/^customization:/d;/^[[:space:]]/d;/^$/d}'"
   ```
   不配置也能正常使用，只是每次用「输入法设定」改动设置后 `git status` 会多出改动。
5. 部署一次。`build/` 不在仓库里（73 MB 编译产物），需要重新编译 44 MB 词库，首次要等几十秒到几分钟：
   ```bat
   start_service.bat
   WeaselDeployer.exe /deploy
   ```

### 不会随仓库一起还原的东西

- `build/`：部署产物，重新部署即可生成。
- `rime_ice.userdb/`：打字积累的学习记录与自造词（词频自适应）。想连它一起还原，就在停止 WeaselServer 后整目录拷贝。
- `installation.yaml`、`user.yaml`：本机安装标识与构建时间戳，Rime 会重新生成。

### 维护提示

- 所有 `*.custom.yaml` 都会入库（`.gitignore` 不再忽略它们），新建的补丁不会被静默漏掉。
- 上游 `.gitignore` 里的 `*private*` 是全局通配：路径中带 `private` 的文件都会被忽略，别用它当词库名。
- 若某个补丁文件**第一次**被写入 `customization:` 头部（或小狼毫升级导致版本号变长），`git status` 会脏一次；跑一下 `git add -A` 即恢复干净，且不会暂存任何内容。
- 修改词库后按上游约定运行 `make -C others/script/ build`；提交信息使用 Conventional Commits。

### 跟随上游更新（可选）

上游雾凇拼音更新词库时，用 `others/script/update-from-upstream.ps1` 同步：

```powershell
pwsh -File others/script/update-from-upstream.ps1 -DryRun   # 先看会改什么，不改任何文件
pwsh -File others/script/update-from-upstream.ps1 -Commit   # 应用并提交，然后 git push
```

- 只同步 Rime 读取的内容（方案、词库、词典、`others/` 资源）。**永远不会覆盖**：`README.md`、`AGENTS.md`、`.gitignore`、`custom_phrase.txt`，以及你独有的三个 `*.custom.yaml` 补丁、`lua/dict_comment_filter.lua`、`opencc/cedict.*`。
- 用 `--depth=1` 只抓上游最新一次提交（约 40 MB；上游完整历史约 247 MB）。远端 `upstream` 是本机 git 配置、**不随仓库分发**，脚本会自动补上。
- 同步后**不需要** `make build`（上游提交的词库已经是排序去重后的结果），重新部署一次即可。
- 同步会覆盖 `cn_dicts/`、`en_dicts/`、`*.schema.yaml`、`default.yaml`、`weasel.yaml` 等被手改过的上游文件 —— 想保留就先提交，同步后用 `git diff` 复查。
- 脚本要求工作区干净（已跟踪文件无未提交改动），否则会直接退出，避免把同步和你的改动混在一起。

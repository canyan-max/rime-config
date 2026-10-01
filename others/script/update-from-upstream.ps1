<#
.SYNOPSIS
    从上游 iDvel/rime-ice（雾凇拼音）同步输入方案、词库与词典资源。

.DESCRIPTION
    本仓库是个人 Rime 配置备份仓库。脚本只同步 Rime 真正读取的内容，
    不会覆盖你自己的东西：三个 *.custom.yaml 补丁、自定义短语 custom_phrase.txt、
    lua/dict_comment_filter.lua、opencc/cedict.*，以及本仓库的说明文档。

    上游完整历史约 247 MB，这里用 --depth=1 只抓最新一次提交（约 40 MB）。
    远端 upstream 是本机 git 配置、不随仓库分发，脚本会自动补上。

.EXAMPLE
    pwsh -File others/script/update-from-upstream.ps1 -DryRun
    只列出会改动哪些文件，不做任何修改。

.EXAMPLE
    pwsh -File others/script/update-from-upstream.ps1 -Commit
    应用上游更新并自动提交（不推送；要推送再执行 git push）。
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Commit
)

$ErrorActionPreference = 'Stop'
$upstreamUrl = 'https://github.com/iDvel/rime-ice.git'

# 同步范围：Rime 读取的方案与词库内容。
# 故意不包含 custom_phrase.txt（可能写了你自己的短语）、README.md、AGENTS.md、.gitignore。
$paths = @(
    '*.schema.yaml', '*.dict.yaml',
    'cn_dicts', 'en_dicts', 'lua', 'opencc', 'others',
    'symbols_v.yaml', 'symbols_caps_v.yaml',
    'default.yaml', 'weasel.yaml', 'squirrel.yaml', 'recipe.yaml'
)

Write-Host '== 1/5 检查仓库状态 ==' -ForegroundColor Cyan
if (-not (Test-Path '.git')) { throw '请在仓库根目录运行本脚本。' }
# 只看已跟踪文件的改动；未跟踪文件（例如临时文件）不阻塞同步
$dirty = git status --porcelain --untracked-files=no
if ($dirty) {
    Write-Host '工作区有未提交的改动，先提交或还原后再同步：' -ForegroundColor Yellow
    $dirty | ForEach-Object { Write-Host "  $_" }
    exit 1
}

Write-Host '== 2/5 准备 upstream 远端 ==' -ForegroundColor Cyan
if ((git remote) -notcontains 'upstream') {
    git remote add upstream $upstreamUrl
    Write-Host "  已添加 upstream: $upstreamUrl"
} else {
    Write-Host "  已存在 upstream: $(git remote get-url upstream)"
}

Write-Host '== 3/5 浅抓取上游最新提交 ==' -ForegroundColor Cyan
git fetch --depth=1 --no-tags upstream main
if ($LASTEXITCODE -ne 0) {
    throw '抓取失败。公司网络下可能需要先配置代理：git config http.proxy http://<代理地址>:<端口>'
}
$upHead = (git log --oneline -1 upstream/main) -join ''
Write-Host "  上游 HEAD: $upHead"

Write-Host '== 4/5 计算差异 ==' -ForegroundColor Cyan
$upFiles = git -c core.quotepath=false ls-tree -r --name-only upstream/main
$effective = @()
foreach ($p in $paths) {
    $pattern = if ($p -match '\.') { $p } else { "$p/*" }
    if ($upFiles | Where-Object { $_ -like $pattern } | Select-Object -First 1) {
        $effective += $p
    } else {
        Write-Host "  上游已无此路径，跳过: $p" -ForegroundColor DarkGray
    }
}

# HEAD -> upstream 的差异：M=内容或权限位不同，A=上游新增；D=仅本仓库有（同步不会动）
$changed = git -c core.quotepath=false diff --name-status HEAD upstream/main -- $effective
$toApply = @($changed | Where-Object { $_ -match '^[MA]\s' })
$localOnly = @($changed | Where-Object { $_ -match '^D\s' })

if ($localOnly.Count -gt 0) {
    Write-Host "  本仓库独有的文件（同步不会动）: $($localOnly.Count) 个" -ForegroundColor DarkGray
}
if ($toApply.Count -eq 0) {
    Write-Host '  已经是最新，无需更新。' -ForegroundColor Green
    exit 0
}
Write-Host "  上游会带来 $($toApply.Count) 处改动：" -ForegroundColor Yellow
$toApply | ForEach-Object { Write-Host "  $_" }

if ($DryRun) {
    Write-Host '（-DryRun：未做任何修改）' -ForegroundColor Green
    exit 0
}

Write-Host '== 5/5 应用上游内容 ==' -ForegroundColor Cyan
git checkout upstream/main -- $effective
if ($LASTEXITCODE -ne 0) { throw '应用上游内容失败。' }

$short = ($upHead -split ' ')[0]
if ($Commit) {
    git add -A
    git commit -q -m "chore: 同步上游方案与词库 ($short)" -m "取自 iDvel/rime-ice $upHead。只同步 Rime 读取的内容，本人的定制补丁、自定义短语与仓库说明保持不变。"
    Write-Host '  已提交（尚未推送）：git push' -ForegroundColor Green
} else {
    Write-Host '  已写入工作区（尚未提交）。下一步：' -ForegroundColor Green
    Write-Host "    git add -A; git commit -m `"chore: 同步上游方案与词库 ($short)`"; git push"
}
Write-Host '  之后重新部署一次即可（WeaselDeployer.exe /deploy）。上游词库已排序去重，不需要 make build。'

<#
Windows 一键安装 + 检查：Godot 4 标准版、Git、VS Code(+godot-tools)、GUT
用法：
  powershell -ExecutionPolicy Bypass -File scripts\setup.ps1 -CheckOnly   # 只检查，不改动
  powershell -ExecutionPolicy Bypass -File scripts\setup.ps1              # 检查并安装缺失项
可选参数：
  -GodotVersion 4.4.1-stable   指定版本（默认取 GitHub 最新正式版）
  -GutRef v9.4.0               指定 GUT 的 tag（默认取最新 release）
  -SkipEditor                  不装 VS Code
  -ProjectDir <path>           GUT 装到该目录的 addons\gut（默认仓库根目录）
#>
param(
  [switch]$CheckOnly,
  [switch]$SkipEditor,
  [string]$GodotVersion = $env:GODOT_VERSION,
  [string]$GutRef = $env:GUT_REF,
  [string]$ProjectDir = (Split-Path -Parent $PSScriptRoot)
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$GodotHome = Join-Path $env:USERPROFILE 'tools\godot'
$results = [ordered]@{}
function Has($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Latest($repo) { (Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'setup' }).tag_name }
function Add-UserPath($dir) {
  $p = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (($p -split ';') -notcontains $dir) {
    [Environment]::SetEnvironmentVariable('Path', "$p;$dir", 'User')
  }
  if (($env:Path -split ';') -notcontains $dir) { $env:Path += ";$dir" }
}
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

# ---------- 1. Godot ----------
function Godot-Ok { (Has godot) -or (Test-Path (Join-Path $GodotHome 'godot.exe')) }
if (-not (Godot-Ok) -and -not $CheckOnly) {
  if (-not $GodotVersion) { $GodotVersion = Latest 'godotengine/godot' }   # 形如 4.4.1-stable
  $name = "Godot_v${GodotVersion}_win64.exe"
  $base = "https://github.com/godotengine/godot/releases/download/$GodotVersion"
  $tmp = Join-Path $env:TEMP "godot-$GodotVersion"
  New-Item -ItemType Directory -Force $tmp | Out-Null
  Write-Host "下载 Godot $GodotVersion ..."
  Invoke-WebRequest "$base/$name.zip" -OutFile "$tmp\g.zip"
  Invoke-WebRequest "$base/SHA512-SUMS.txt" -OutFile "$tmp\sums.txt"
  $want = ((Get-Content "$tmp\sums.txt") | Where-Object { $_ -match [regex]::Escape("$name.zip") } | Select-Object -First 1) -split '\s+' | Select-Object -First 1
  $got = (Get-FileHash "$tmp\g.zip" -Algorithm SHA512).Hash.ToLower()
  if (-not $want -or $want.ToLower() -ne $got) { throw "Godot 校验和不匹配，已中止" }
  Expand-Archive "$tmp\g.zip" -DestinationPath $tmp -Force
  New-Item -ItemType Directory -Force $GodotHome | Out-Null
  Copy-Item "$tmp\$name" (Join-Path $GodotHome 'godot.exe') -Force
  $con = Get-ChildItem $tmp -Filter '*_console.exe' | Select-Object -First 1
  if ($con) { Copy-Item $con.FullName (Join-Path $GodotHome 'godot_console.exe') -Force }
  Add-UserPath $GodotHome
}
$results['Godot'] = if (Godot-Ok) {
  # godot.exe 是 GUI 程序，在终端里不输出文本；优先用 console 版读版本号
  $con = Join-Path $GodotHome 'godot_console.exe'
  $exe = if (Test-Path $con) { $con } else { 'godot' }
  try { (& $exe --version 2>&1 | Select-Object -First 1) } catch { 'installed' }
} else { 'MISSING' }

# ---------- 2. Git ----------
if (-not (Has git) -and -not $CheckOnly) {
  if (-not (Has winget)) { throw "没有 winget，请手动安装 Git" }
  winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
  Refresh-Path
}
$results['Git'] = if (Has git) { (git --version) } else { 'MISSING' }

# ---------- 3. VS Code + godot-tools（可选） ----------
if (-not $SkipEditor) {
  if (-not (Has code) -and -not $CheckOnly) {
    if (Has winget) {
      winget install --id Microsoft.VisualStudioCode -e --silent --accept-package-agreements --accept-source-agreements
      Refresh-Path
    }
  }
  if (Has code) {
    if (-not $CheckOnly -and -not ((code --list-extensions) -contains 'geequlim.godot-tools')) {
      code --install-extension geequlim.godot-tools --force | Out-Null
    }
    $ext = if ((code --list-extensions) -contains 'geequlim.godot-tools') { 'godot-tools OK' } else { 'godot-tools MISSING' }
    $results['VS Code'] = "installed, $ext"
  } else { $results['VS Code'] = 'MISSING' }
}

# ---------- 4. GUT ----------
$gutDir = Join-Path $ProjectDir 'addons\gut'
if (-not (Test-Path $gutDir) -and -not $CheckOnly) {
  if (-not (Has git)) { throw "安装 GUT 需要 git" }
  if (-not $GutRef) { $GutRef = Latest 'bitwes/Gut' }
  $tmp = Join-Path $env:TEMP "gut-$GutRef"
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  git clone --quiet --depth 1 --branch $GutRef https://github.com/bitwes/Gut.git $tmp
  New-Item -ItemType Directory -Force (Join-Path $ProjectDir 'addons') | Out-Null
  Copy-Item (Join-Path $tmp 'addons\gut') $gutDir -Recurse -Force
}
$results['GUT'] = if (Test-Path $gutDir) { "installed at $gutDir" } else { 'MISSING' }

# ---------- 汇总 ----------
Write-Host "`n===== 检查结果 ====="
$results.GetEnumerator() | ForEach-Object { '{0,-10} {1}' -f $_.Key, $_.Value }
if (-not (Test-Path (Join-Path $ProjectDir 'project.godot'))) {
  Write-Host "`n提示：$ProjectDir 下还没有 project.godot；GUT 需在项目创建后于 项目设置 > 插件 中启用。"
}
if ($results.Values -contains 'MISSING') { exit 1 }

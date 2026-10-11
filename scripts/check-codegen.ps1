# FRB codegen 一致性检查（防止生成代码被手改、或改完 Rust API 忘记重新生成）。
#
# 背景：2026-08-17~08-21 的 Rust 五层目录迁移漏改了 flutter_rust_bridge.yaml，
#       并手工替换 rust/src/frb_generated.rs 的模块路径，导致 codegen 两个月产出空壳
#       而无人发现。本脚本把「生成物必须能由源码复现」变成可执行的检查。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts\check-codegen.ps1
#
# 何时运行：改动 rust/src/api/**（FFI 入口）或 flutter_rust_bridge.yaml 之后必须运行；
#           生成产物有变化时，连同源码一起提交。
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  if (-not (Get-Command flutter_rust_bridge_codegen -ErrorAction SilentlyContinue)) {
    Write-Host '未找到 flutter_rust_bridge_codegen，跳过检查（请先安装 codegen 工具）' -ForegroundColor Yellow
    exit 0
  }

  Write-Host '运行 flutter_rust_bridge_codegen generate ...'
  & flutter_rust_bridge_codegen generate | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host 'codegen 执行失败' -ForegroundColor Red
    exit 1
  }

  $targets = @('lib/generated', 'rust/src/frb_generated.rs')
  git diff --quiet -- $targets
  $unstaged = $LASTEXITCODE
  git diff --cached --quiet -- $targets
  $staged = $LASTEXITCODE
  if ($unstaged -ne 0 -or $staged -ne 0) {
    Write-Host ''
    Write-Host '生成产物与仓库内容不一致：要么手改了生成代码，要么改了 Rust API 却没提交重新生成的结果。' -ForegroundColor Red
    Write-Host '处理：确认 Rust 侧改动无误后，提交 codegen 重新生成的产物（禁止手改 lib/generated 与 frb_generated.rs）。' -ForegroundColor Red
    git diff --stat -- $targets
    exit 1
  }

  Write-Host 'codegen 一致性检查通过'
}
finally {
  Pop-Location
}

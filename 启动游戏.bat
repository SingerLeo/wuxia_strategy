@echo off
rem 双击启动游戏。Godot 在 %USERPROFILE%\tools\godot\（scripts\setup.ps1 安装的）。
cd /d "%~dp0"
start "" "%USERPROFILE%\tools\godot\godot.exe" --path .

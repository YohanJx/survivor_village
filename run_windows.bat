@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
pushd "%~dp0"
if errorlevel 1 goto directory_error

if not exist "project.godot" goto project_error
set "godot_executable="

rem An explicit argument or GODOT_EXE takes priority over automatic discovery.
if not "%~1"=="" (
	call :use_godot "%~1"
	if not defined godot_executable goto path_error
)
if not defined godot_executable if defined GODOT_EXE (
	call :use_godot "%GODOT_EXE%"
	if not defined godot_executable goto path_error
)
for %%G in ("%~dp0godot.exe" "%~dp0Godot*.exe" "%~dp0tools\godot\godot.exe" "%~dp0tools\godot\Godot*.exe") do call :use_godot "%%~G"
if not defined godot_executable for /f "delims=" %%G in ('where godot.exe Godot*.exe 2^>nul') do call :use_godot "%%G"
if not defined godot_executable goto godot_missing

echo 正在导入项目资源，首次启动可能需要稍等……
"%godot_executable%" --headless --editor --path "%CD%" --import
if errorlevel 1 goto import_error

echo 正在启动余烬村庄……
"%godot_executable%" --path "%CD%"
if errorlevel 1 goto launch_error
popd
exit /b 0

:use_godot
if defined godot_executable exit /b 0
if not exist "%~1" exit /b 0
if /i not "%~x1"==".exe" exit /b 0
set "godot_executable=%~f1"
exit /b 0

:godot_missing
echo 未找到 Godot，正在打开官方下载页面。
echo 请下载标准版 Godot 4.5，解压后将 Godot 的 exe 放到本脚本旁边。
echo 也可以放到 tools\godot 文件夹中，无需改名；然后再次双击本脚本。
echo 官网历史版本入口：https://godotengine.org/download/archive/4.5-stable/
start "" "https://godotengine.org/download/windows/"
goto failure

:path_error
echo 指定的 Godot 路径无效，请提供完整的 exe 路径。
goto failure

:project_error
echo 缺少 project.godot，请解压完整项目后再运行本脚本。
goto failure

:import_error
echo 项目资源导入失败，请检查上方错误信息并使用 Godot 4.5 重试。
goto failure

:launch_error
echo 游戏启动或运行失败，请检查上方错误信息。
goto failure

:directory_error
echo 无法打开项目目录，请检查路径和访问权限。
pause
exit /b 1

:failure
pause
popd
exit /b 1

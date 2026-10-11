#!/bin/bash
# Finder opens .command files in Terminal. Keep paths quoted for downloaded projects.
set -u
shopt -s nullglob


fail() {
	printf '\n%s\n' "$1" >&2
	if [[ -t 0 ]]; then
		read -r -p "按回车键关闭……" _
	fi
	exit 1
}


use_godot() {
	local candidate="$1"
	if [[ -n "$godot_executable" ]]; then
		return
	fi
	if [[ -d "$candidate" ]]; then
		candidate="$candidate/Contents/MacOS/Godot"
	fi
	if [[ -f "$candidate" && -x "$candidate" ]]; then
		godot_executable="$candidate"
	fi
}


project_directory="$(cd -- "$(dirname -- "$0")" && pwd)" || fail "无法打开项目目录。"
cd -- "$project_directory" || fail "无法进入项目目录。"
[[ -f "project.godot" ]] || fail "缺少 project.godot，请解压完整项目后再运行。"
godot_executable=""

if [[ $# -gt 0 ]]; then
	use_godot "$1"
	shift
	[[ -n "$godot_executable" ]] || fail "指定的 Godot 路径无效，请提供 app 或可执行文件路径。"
elif [[ -n "${GODOT_EXE:-}" ]]; then
	use_godot "$GODOT_EXE"
	[[ -n "$godot_executable" ]] || fail "GODOT_EXE 路径无效，请提供 app 或可执行文件路径。"
fi

for candidate in "$project_directory"/Godot*.app "$project_directory"/godot \
	"$project_directory"/tools/godot/Godot*.app "$project_directory"/tools/godot/godot \
	/Applications/Godot*.app "$HOME"/Applications/Godot*.app; do
	use_godot "$candidate"
done

if [[ -z "$godot_executable" ]]; then
	use_godot "$(command -v godot || true)"
fi

if [[ -z "$godot_executable" ]]; then
	printf '%s\n' "未找到 Godot，正在打开官方下载页面。" \
		"请下载 Godot 4.5 标准版，将解压后的 Godot.app 放入「应用程序」或本项目目录，然后再次双击。" \
		"历史版本：https://godotengine.org/download/archive/4.5-stable/"
	open "https://godotengine.org/download/macos/" || fail "无法打开浏览器，请手动访问上方官网。"
	fail "安装完成后请重新运行本脚本。"
fi

printf '%s\n' "正在导入项目资源，首次启动可能需要稍等……"
"$godot_executable" --headless --editor --path "$project_directory" --import \
	|| fail "项目资源导入失败，请检查上方错误信息并使用 Godot 4.5 重试。"

printf '%s\n' "正在启动余烬村庄……"
launch_log="${TMPDIR:-/tmp}/ember_village_launch_$(date +%Y%m%d_%H%M%S)_$$.log"
nohup "$godot_executable" --path "$project_directory" "$@" > "$launch_log" 2>&1 < /dev/null &
game_pid=$!
sleep 1
if ! kill -0 "$game_pid" 2>/dev/null; then
	wait "$game_pid" || {
		cat "$launch_log" >&2
		fail "游戏启动失败，请检查上方错误信息。"
	}
fi
printf '游戏日志：%s\n' "$launch_log"

# Close only the launcher's Terminal tab after this shell has finished.
if [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" && -t 1 ]]; then
	terminal_tty="$(tty)"
	nohup /usr/bin/osascript - "$terminal_tty" > /dev/null 2>&1 < /dev/null <<'APPLESCRIPT' &
on run arguments
	delay 1
	set launcherTty to item 1 of arguments
	tell application "Terminal"
		repeat with terminalWindow in windows
			repeat with terminalTab in tabs of terminalWindow
				if tty of terminalTab is launcherTty then
					close terminalTab
					return
				end if
			end repeat
		end repeat
	end tell
end run
APPLESCRIPT
fi

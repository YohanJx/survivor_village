#!/usr/bin/env python3
"""Render real game screenshots without showing a window or taking desktop focus on macOS."""
from __future__ import annotations

import argparse
import os
import plistlib
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=Path("/Applications/Godot4.5.app/Contents/MacOS/Godot"))
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("This quiet launcher currently supports macOS only; it never falls back to a visible window.")
    binary = args.godot.resolve()
    app = binary.parent.parent.parent
    if not binary.is_file() or app.suffix != ".app":
        parser.error("--godot must point to a Godot binary inside a macOS .app bundle.")
    source = Path(__file__).resolve().parent.parent
    output = source / "test-results"
    output.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="emberhaven_capture_") as temporary:
        project = Path(temporary)
        for folder in ("assets", "data", "scenes", "scripts", "tests"):
            shutil.copytree(source / folder, project / folder)
        settings = (source / "project.godot").read_text(encoding="utf-8")
        settings = re.sub(r'config/name="[^"]+"', 'config/name="Emberhaven Background Capture"', settings)
        settings = re.sub(r"window/size/mode=\d+", "window/size/mode=1", settings)
        (project / "project.godot").write_text(settings, encoding="utf-8")
        results = project / "test-results"
        results.mkdir()
        imported = subprocess.run(
            [str(binary), "--headless", "--path", str(project), "--editor", "--import"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90,
        )
        (output / "survival_capture_import.log").write_text(imported.stdout, encoding="utf-8")
        if imported.returncode or "ERROR:" in imported.stdout or "SCRIPT ERROR:" in imported.stdout:
            print("Background capture import failed. See test-results/survival_capture_import.log.")
            return 1
        hidden_app = project / "BackgroundCapture.app"
        contents = hidden_app / "Contents"
        (contents / "MacOS").mkdir(parents=True)
        shutil.copy2(binary, contents / "MacOS" / "Godot")
        for folder in ("Resources", "Frameworks"):
            original_folder = app / "Contents" / folder
            if original_folder.exists():
                shutil.copytree(original_folder, contents / folder)
        info = plistlib.loads((app / "Contents" / "Info.plist").read_bytes())
        info["CFBundleIdentifier"] = "org.emberhaven.backgroundcapture"
        info["CFBundleExecutable"] = "Godot"
        info["LSBackgroundOnly"] = True
        info["LSUIElement"] = True
        (contents / "Info.plist").write_bytes(plistlib.dumps(info))
        subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(hidden_app)], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        log = results / "survival_capture.log"
        def foreground() -> str:
            state = subprocess.check_output(["/usr/bin/lsappinfo", "front"], text=True).strip()
            return subprocess.check_output(
                ["/usr/bin/lsappinfo", "info", "-only", "pid,name", state], text=True
            ).strip()

        previous_foreground = foreground()
        if not re.search(r'"pid"=\d+', previous_foreground):
            print("Cannot verify system foreground state; capture was not launched.")
            return 1
        foreground_states = [previous_foreground]
        guard = project / "background_capture.dylib"
        subprocess.run([
            "/usr/bin/clang", "-dynamiclib", "-framework", "Cocoa",
            str(source / "tools" / "background_capture.m"), "-o", str(guard)
        ], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        environment = os.environ.copy()
        environment["DYLD_INSERT_LIBRARIES"] = str(guard)
        with log.open("w", encoding="utf-8") as stream:
            process = subprocess.Popen([
                str(contents / "MacOS" / "Godot"), "--path", str(project),
                "--script", "tests/capture_background_ui.gd", "--disable-render-loop",
                "--audio-driver", "Dummy"
            ], env=environment, stdout=stream, stderr=subprocess.STDOUT)
        completed = results / "capture_complete.txt"
        deadline = time.monotonic() + 45
        while not completed.exists() and process.poll() is None and time.monotonic() < deadline:
            foreground_states.append(foreground())
            time.sleep(0.1)
        if not completed.exists() and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        for file in results.iterdir():
            if file.suffix in (".png", ".log", ".txt") and file.name != "capture_pid.txt":
                shutil.copy2(file, output / file.name)
        if not completed.exists():
            print("Background capture timed out. See test-results/survival_capture.log.")
            return 1
        process.wait(timeout=10)
        foreground_states.append(foreground())
        capture_pid = int((results / "capture_pid.txt").read_text(encoding="utf-8"))
        foreground_details = list(dict.fromkeys(foreground_states))
        capture_never_foreground = all(
            (match := re.search(r'"pid"=(\d+)', detail)) is not None
            and int(match.group(1)) != capture_pid for detail in foreground_details
        )
        (output / "survival_capture_focus.log").write_text(
            "Capture process PID: " + str(capture_pid) + "\n" + "\n".join(foreground_details)
            + "\nCapture process never foreground: " + str(capture_never_foreground), encoding="utf-8"
        )
        if not capture_never_foreground:
            print("Capture process took foreground focus; quiet verification failed.")
            return 1
        report = completed.read_text(encoding="utf-8")
        print(report)
        log_text = log.read_text(encoding="utf-8") if log.exists() else ""
        return 0 if (
            ", 0 failures" in report and "ERROR:" not in log_text
            and "BACKGROUND GUARD: activation prohibited; native windows suppressed" in log_text
            and process.returncode == 0
        ) else 1


if __name__ == "__main__":
    raise SystemExit(main())

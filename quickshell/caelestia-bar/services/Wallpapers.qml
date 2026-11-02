pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property string shadowsCurrentPath: `${Paths.home}/.cache/hyprquickpaper-current`
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    readonly property string current: actualCurrent
    property string actualCurrent
    property string shadowsCurrent
    property string legacyCurrent
    property string pendingSetPath

    function getCategoryFor(w: FileSystemEntry): string {
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function setRandom(): void {
        if (selectRandomProc.running) {
            console.warn("Random wallpaper selection is already running");
            return;
        }
        selectRandomProc.selection = "";
        selectRandomProc.exec([`${Paths.home}/.local/bin/phantom-wallpaper-select`, Paths.wallsdir, "--current", actualCurrent]);
    }

    function setWallpaper(path: string): void {
        if (!path) {
            console.warn("Cannot set an empty wallpaper path");
            return;
        }
        if (setWallpaperProc.running) {
            pendingSetPath = path;
            return;
        }
        setWallpaperProc.exec(["bash", `${Paths.home}/.config/quickshell/hyprquickpaper/commands.sh`, path]);
    }

    function updateCurrent(): void {
        actualCurrent = shadowsCurrent || legacyCurrent || fallback;
    }

    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    FileView {
        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.legacyCurrent = text().trim();
            root.updateCurrent();
        }
        onLoadFailed: {
            root.legacyCurrent = "";
            root.updateCurrent();
        }
    }

    FileView {
        path: root.shadowsCurrentPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.shadowsCurrent = text().trim();
            root.updateCurrent();
        }
        onLoadFailed: {
            root.shadowsCurrent = "";
            root.updateCurrent();
        }
    }

    Process {
        id: setWallpaperProc

        onExited: code => {
            if (code !== 0)
                console.warn(`Wallpaper application failed (exit ${code})`);
            if (root.pendingSetPath) {
                const next = root.pendingSetPath;
                root.pendingSetPath = "";
                Qt.callLater(() => root.setWallpaper(next));
            }
        }
    }

    Process {
        id: selectRandomProc

        property string selection

        stdout: StdioCollector {
            onStreamFinished: selectRandomProc.selection = text.trim()
        }

        onExited: code => {
            if (code !== 0 || !selection) {
                console.warn(`Random wallpaper selection failed (exit ${code})`);
                return;
            }
            root.setWallpaper(selection);
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Images
    }

}

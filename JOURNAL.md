# JOURNAL — phantom-shell

Журнал выполненного. Новые записи добавляются сверху. Старые записи не переписывать.

---

## 2026-11-02 — этап 1: горизонтальный бар

**Сделано:**
- Вендорен `modules/bar` (32 файла) в `quickshell/caelestia-bar`, коммит `7edc9ba` (без изменений, GPL-3).
- Симлинки `components`, `services`, `utils`, `assets` → `/etc/xdg/quickshell/caelestia/*`.
- `config/BarConfig.qml` — singleton: `thickness: 36`, `padding: 4`, `launcherCommand`.
- `shell.qml` — `PanelWindow` сверху на каждый монитор, `exclusiveZone`, скрытие в fullscreen (по монитору, с учётом special workspace).
- Переписаны: `Bar.qml`, `BarWrapper.qml`, `Clock.qml`, `ActiveWindow.qml`, `StatusIcons.qml`, `Tray.qml`, `Power.qml`, `OsIcon.qml`, `status/BluetoothStatus.qml`, `status/LockStatus.qml`, `workspaces/{Workspaces,Workspace,SpecialWorkspaces}.qml`.
- Удалены `workspaces/{ActiveIndicator,GapMarkers,OccupiedBg}.qml` — функциональность в `Workspace.qml` (подсветка активного, фон занятых, иконки окон).
- `popouts/Wrapper.qml` — заглушка с API для этапа 2.
- Логотип запускает `rofi -show drun` (hyprlauncher не установлен).

**Проверки:**
- `qs -p ~/Projects/phantom-shell/quickshell/caelestia-bar`: конфиг загружается, ошибок нет.
- `hyprctl layers`: `caelestia-bar` 1920x36 (eDP-1) и 2560x36 (DP-3), y=0.
- Fullscreen на DP-3 (`hl.dsp.window.fullscreen()`): бар DP-3 исчезает, бар eDP-1 остаётся; после выхода — оба на месте.
- Скриншоты: `/tmp/opencode/bar-h1.png`, `bar-dp3.png`, `bar-ws2.png`.
- Трей: шеврон раскрытия появляется (SystemTray items перехвачены), Caelestia на время теста остановлена.

**Проблемы/наблюдения:**
- `pkill -f 'qs -c caelestia'` убивает и собственную оболочку команды (паттерн есть в её cmdline). Использовать `pkill -f '^qs -c caelestia'`.
- `LazyListView` из `Caelestia.Components` — вертикальный C++-список без `orientation`, поэтому воркспейсы переведены на `Row`+`Repeater`.
- Предупреждение `Ignoring unresolvable import .../modules/drawers from components/controls/Menu.qml` — `Menu` пока не используется, разобрать на этапе 2.
- Колесо и клики не проверены: нет инструмента синтетического ввода.
- Caelestia сейчас остановлена, бар запущен отдельным `qs -p`; вернуть: `caelestia shell -d`.

**Дальше:** этап 2 — slim-`Wrapper`, попоуты, позиционирование по X.

---

## 2026-11-02 — git-базовая линия

**Сделано:**
- `main`: коммит `4bbd7d8` — `PROJECT.md`, `JOURNAL.md`, `AGENTS.md`.
- Тег `upstream-2.97` на коммите `4202205` (чистый upstream).
- Ветка `feat/caelestia-bar` — для всей работы по бару.
- В `PROJECT.md` добавлен раздел «Git и откат».

**Проверки:** `git status` чистый, `git log --oneline --decorate` показывает `main` и `feat/caelestia-bar` на одном коммите.

**Дальше:** этап 1 — горизонтальный бар.

---

## 2026-11-02 — спайк бара (этап 0)

**Сделано:**
- Создан `/tmp/opencode/caelestia-bar` с симлинками `services`, `components`, `utils`, `assets`, `modules` → `/etc/xdg/quickshell/caelestia/*`.
- `shell.qml`: `ShellRoot` → `Variants` по экранам → `StyledWindow` (namespace `caelestia-bar`, `exclusiveZone`, `implicitWidth`) с `BarWrapper` + `BarPopouts.Wrapper`.
- Запуск `qs -p /tmp/opencode/caelestia-bar`.

**Проверки:**
- Конфиг загрузился без QML-ошибок; в логе только безобидные предупреждения QQuickPixmapReader.
- `hyprctl layers`: окна `caelestia-bar` 60x1420 на DP-3 (4410,10) и 60x1060 на eDP-1 (1850,10).
- `qs.*` через симлинки резолвится, `Caelestia.Config` работает вне шелла Caelestia.
- Скриншот `/tmp/opencode/bar-spike.png` — бар отрисован.

**Проблемы/наблюдения:**
- Отступ y=10 — следствие эксклюзивных зон Caelestia (`caelestia-border-exclusion`), не баг.
- Спайк перехватил StatusNotifierItems (трей); процесс убит, Caelestia не тронута.

**Дальше:** этап 1 — горизонтальный бар.

---

## 2026-11-02 — исследование, структура, документы

**Сделано:**
- Исследован бар Caelestia: `/etc/xdg/quickshell/caelestia/modules/bar` — 24 файла, 3170 строк, вертикальный справа, с попоутами.
- Выяснены зависимости: `qs.services` (17 файлов), `qs.components` (~40), `qs.utils`, C++ модули `Caelestia.*` в `/usr/lib/qt6/qml/Caelestia`.
- Наивная зависимость бара — 254 из 282 QML-файлов (из-за `popouts/Wrapper.qml` → `qs.modules.nexus`/`windowinfo`). Решение: slim-Wrapper.
- Проверено текущее состояние: активна Caelestia (`qs -c caelestia`, pid 1330), waybar не запущен, конфиг Hyprland — Caelestia.
- Созданы `/home/rassvet/Projects/shadows-shell` (upstream V2.97, HEAD `4202205`) и `/home/rassvet/Projects/phantom-shell` (копия, `origin` → `upstream`).
- Созданы `PROJECT.md`, `JOURNAL.md`, `AGENTS.md`, скилл `~/.config/opencode/skills/phantom-shell/SKILL.md`.

**Файлы:** `PROJECT.md`, `JOURNAL.md`, `AGENTS.md`, `~/.config/opencode/skills/phantom-shell/SKILL.md`.

**Проверки:** `git -C ~/Projects/phantom-shell remote -v` → только `upstream`; рабочее дерево чистое.

**Проблемы:** нет.

**Дальше:** этап 0 — спайк `/tmp/opencode/caelestia-bar` (симлинки + минимальный `shell.qml` + `BarWrapper`).

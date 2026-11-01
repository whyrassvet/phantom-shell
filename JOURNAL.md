# JOURNAL — phantom-shell

Журнал выполненного. Новые записи добавляются сверху. Старые записи не переписывать.

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

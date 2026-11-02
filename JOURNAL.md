# JOURNAL — phantom-shell

Журнал выполненного. Новые записи добавляются сверху. Старые записи не переписывать.

---

## 2026-11-02 — размер и форма бара

- `config/BarConfig.qml`: высота 40 px, отступ 4 px, внутренняя высота 32 px; прежнее решение о 60 px отменено.
- `Tray.qml`, `StatusIcons.qml`, `Clock.qml`, `workspaces/Workspaces.qml`: радиус в половину высоты; отдельный свёрнутый трей квадратный и потому круглый, группы остаются горизонтальными плашками.
- `workspaces/Workspace.qml`: подложка номера шириной и высотой `indicatorSize` (28 px при стандартных токенах), меньше группы; `Clock.qml`: цвет текста `m3secondary`, как у значков.
- `git diff --check` пройден; Qt 6 `qmllint` выдаёт предупреждения о неразрешённых `qs.*` импортах вне Quickshell, поэтому полноценную проверку не заменяет. Caelestia не останавливалась, визуальная и интерактивная проверка новой версии остаются.
- Резервные копии: `/tmp/opencode/phantom-backup-40px/`.

---

## 2026-11-02 — корректировка бара и автозапуска

- `BarConfig.qml`: высота 60 px, отступ 10 px, фон элементов 40 px; прежнее решение о 36 px отменено.
- `Workspace.qml`: номера вместо индикаторов и иконок приложений; имена special workspace сохранены.
- `Bar.qml`, `ActiveWindow.qml`: центрирование текста по середине монитора, ограничение по свободному месту; `Tray.qml` и обработка наведения: круглый шеврон и определение пункта по фактической геометрии.
- `StatusIcons.qml`: микрофон перед раскладкой независимо от их исходного порядка. `config/hypr/hyprland.lua`: `systemctl --user start swaync.service` вместо прямого запуска.
- Проверки: `luac -p`, `git diff --check`, тестовый бар на обоих мониторах (1920×60 и 2560×60), визуальная проверка центрирования и оформления; Caelestia возвращена. В логе запуска были предупреждения StatusNotifierItem и Qt о потоках, а при перезагрузке QML — предупреждения `Time.qml` о временно неопределённых значениях; конфиг загрузился. Интерактивная проверка трея после изменений и проверка нагрузки swaync после нового автозапуска не выполнялись.
- Резервные копии до правок: `/tmp/opencode/phantom-backup-20261102/`. Интеграция waybar → бар остаётся этапом 3.

---

## 2026-11-02 — этап 2: попоуты

**Сделано:**
- `popouts/Wrapper.qml` переписан: slim-версия без `qs.modules.nexus`/`qs.modules.windowinfo`, `PopoutState` + `Content`, `currentCenter` по X, `close()` по Escape. Отсоединённые панели (nexus/windowinfo) отключены: `detach()` просто закрывает попоут.
- `shell.qml`: второе окно `StyledWindow` (`caelestia-popouts`) — fullscreen, `WlrLayer.Overlay`, `ExclusionMode.Ignore`, `exclusiveZone: -1`; `mask: Region` по прямоугольнику попоута (ввод только внутри панели, остальное проходит сквозь); `visible: pops.hasCurrent`.
- Позиционирование: `y = BarConfig.thickness + BarConfig.padding`, `x = clamp(currentCenter - width/2, padding, screenWidth - width - padding)`.
- Фон попоута: `Elevation` (level 2) + `StyledRect` с `Colours.tPalette.m3surface`, radius `Tokens.rounding.extraLarge`. В Caelestia фон рисуют `PanelBg`-блобы в окне drawers — их нет, поэтому простой прямоугольник.
- Закрытие: таймер 400 мс после ухода курсора с бара и попоута (`HoverHandler` в окне попоутов), смена `Hypr.activeToplevel`, fullscreen на мониторе, `close()`.
- `BarWrapper.qml`: `MouseArea` (`acceptedButtons: Qt.NoButton`, `hoverEnabled`) — hover → `checkPopout(x)`, wheel → `handleWheel(x, delta)`.
- `config/BarConfig.qml`: `powerCommand` (пусто = переключение `screenState.session`); `Power.qml` при заданной команде запускает её.
- `modules/drawers/qmldir` — заглушка, убирает `Ignoring unresolvable import ... modules/drawers` от `components/controls/Menu.qml`.

**Проверки (реальный ввод через `ydotoold`, демон запускался пользователем и после теста остановлен):**
- Загрузка: в логе только INFO, ни одного WARN/ERROR.
- Hover по иконкам звука/раскладки/сети/BT/батареи на eDP-1 и DP-3 → попоут под иконкой, прижатие к правому краю экрана.
- Переход с одной иконки на другую — содержимое меняется; уход на рабочий стол — попоут закрывается через 400 мс; курсор внутри попоута — остаётся открытым.
- Клик по кнопке «Rescan networks» внутри попоута срабатывает (mask/input region корректны).
- Трей (Riff): первый hover раскрывает, hover по иконке соседнего элемента открывает меню (Show/Hide, Play/Pause, Quit).
- Колесо: левая половина бара — громкость (0.79↔0.90), правая — яркость (100%→90%).
- Логотип: клик запускает `rofi -show drun`.
- Fullscreen (`hl.dsp.window.fullscreen()` на kitty): бар своего монитора и попоут исчезают, второй монитор не затронут; после выхода всё возвращается.
- Скриншоты: `/tmp/opencode/final-popout.png`, `hover-network3.png`, `dp3-kb3.png`, `tray-menu2.png`, `click-after.png`.

**Проблемы/наблюдения:**
- `ydotool mousemove --absolute` не работает без отключения ускорения мыши; для тестов использовались относительные перемещения в цикле до нужной точки (`hyprctl cursorpos` как обратная связь).
- При раскрытии трея иконки сдвигаются влево (ширина трея растёт, spacer сжимается) — при наведении на пункт меню это надо учитывать.
- `wirelesspassword` не проверен: в окружении нет защищённой сети, на которой можно безопасно проверить ввод пароля. Окну попоутов для него выставляется `WlrKeyboardFocus.OnDemand`.
- В `Content.qml` один делегат статуса логируется как `undefined` — это микрофон (`name: "audio"`, ширина 0 при выключенном индикаторе), не ошибка.
- Питание без `powerCommand` включает `screenState.session`, но панели сессии в форке нет — кнопка визуально ничего не делает до портирования drawers/session.

**После тестов:** отдельный бар остановлен, Caelestia возвращена (`caelestia shell -d`, слои `caelestia-background`, `caelestia-drawers` на месте).

**Дальше:** этап 3 — интеграция в shadows-shell (waybar → бар).

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

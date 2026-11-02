# JOURNAL — phantom-shell

Журнал выполненного. Новые записи добавляются сверху. Старые записи не переписывать.

---

## 2026-11-02 — приватная установка плагинов и запускатель

- По отдельному подтверждению `cmake --install` выполнен только в `/tmp/opencode/phantom-plugin-install.UCtGKa`; системные каталоги не менялись. В этой установке `ldd` разрешил зависимости `config`, `core`, `settings` в приватный каталог.
- `tests/smoke-caelestia-plugin.sh` принимает установленный префикс и QML-путь; в bubblewrap со скрытым системным `/usr/lib/qt6/qml/Caelestia` и без унаследованных `LD_LIBRARY_PATH`, `LD_PRELOAD`, `QML2_IMPORT_PATH` загружены 17 библиотек из приватной установки. Это не проверка бара или полного отсутствия CLI.
- `bin/phantom-bar` проверяет конфиг, локальные модули и библиотеки, задаёт приватные `QML_IMPORT_PATH` и `LD_LIBRARY_PATH` только для дочернего процесса и запускает `qs -p`. `tests/phantom-bar-launcher.sh` с заглушкой `qs` проверил пути и аргументы, а также отказ при отсутствии модулей. Настоящий бар через запускатель не запускался, установщик и автозапуск сессии с ним не интегрированы.
- Исходники теста сборки и инструкция обновлены. Резервные копии документов и прежних версий тестов: `/tmp/opencode/phantom-private-launch-backup/`. Дальше — сборка и установка плагинов через установщик, изоляция собственных настроек/CLI и проверка бара в среде без Caelestia.

---

## 2026-11-02 — проверка приватных плагинов

- Добавлены `tests/caelestia-plugin-smoke.cpp` и `tests/smoke-caelestia-plugin.sh`; команды запуска включены в `vendor/caelestia-shell-plugin-v2.5.0/PHANTOM-SOURCE.md`.
- Повторяемый тест создаёт отдельный HOME, запускает Qt offscreen через bubblewrap, скрывает `/usr/lib/qt6/qml/Caelestia`, импортирует QML-модули и проверяет `/proc/self/maps`: все загруженные `libcaelestia` должны быть из переданного каталога сборки. Результат: `Loaded 17 Caelestia libraries from the private build`.
- Это проверка импортов, не запуска бара и не тест отсутствия пакетов целиком: системные библиотеки доступны, а исполняемый файл `caelestia` не скрывался. Установку и переменные окружения пользовательской сессии не меняли. Остались приватная установка и интеграция плагинов, устранение CLI и чужих настроек, полноценный тест. Документы сохранены до правок в `/tmp/opencode/phantom-plugin-smoke-backup/`.

---

## 2026-11-02 — локальные QML и ресурсы

- Четыре отслеживаемых симлинка `quickshell/caelestia-bar/{components,services,utils,assets}` заменены неизменёнными копиями из тега Caelestia v2.5.0, commit `d999d4878ee4cec134168e60d913714566a8cfa6`; добавлены `LICENSE` и `UPSTREAM.md`, лицензии ресурсов сохранены. Это полный временный перенос четырёх каталогов, не минимизированная транзитивная выборка.
- `install/lib/phantom-bar.sh`: копирование локальных каталогов без зависимости от пакетных путей, отказ при симлинках в источнике и путях назначения. Автоматической миграции ранее установленных пакетных симлинков нет: установщик безопасно откажется, а не удалит их.
- Проверки: `diff -qr` для четырёх каталогов с тегом без различий, `find` не обнаружил симлинков в дереве бара, подсчёт подтвердил что все 93 файла каталогов добавлены в Git. Изолированный тест функции установки скопировал локальные файлы, а конфликтующий симлинк назначения не был перезаписан; `bash -n install.sh install/lib/phantom-bar.sh` пройден. `git diff --check` отмечает пустую строку в конце неизменённого upstream-файла `utils/scripts/fuzzysort.js`.
- Действующую Caelestia и пакеты не меняли, визуального запуска после переноса не проводили. Библиотеки C++ всё ещё системные при обычном запуске, вызовы CLI и чужие настройки не устранены. Резервные копии прежних симлинков и документов: `/tmp/opencode/phantom-qml-vendor-backup/`.

---

## 2026-11-02 — исходники плагинов для автономности

- В `vendor/caelestia-shell-plugin-v2.5.0/` добавлены неизменённые `plugin/`, корневой `CMakeLists.txt` и `LICENSE` из `caelestia-dots/shell` v2.5.0, commit `d999d4878ee4cec134168e60d913714566a8cfa6`; происхождение, лицензия и команды сборки описаны в `PHANTOM-SOURCE.md`. Это ещё не интеграция в установщик.
- Установленный `caelestia-shell` имеет версию 2.5.0-1. `diff -qr` между четырьмя каталогами пакета (`components`, `services`, `utils`, `assets`) и тегом v2.5.0 не выявил различий. Это не доказывает идентичность C++ исходников пакету.
- Изолированная конфигурация CMake с `ENABLE_MODULES=plugin`, `VERSION=2.5.0` и сборка `cmake --build ... --parallel 2` успешно завершились в `/tmp/opencode/phantom-caelestia-plugin-build`. `ldd` для собранного `libcaelestia-configplugin.so` показал собственные библиотеки `config`, `core` и `settings` из каталога сборки. Установка и запуск бара с этими библиотеками не проверены; системные библиотеки и пакет Caelestia остаются на машине.
- Дальше: перенести QML и ресурсы, устранить вызовы CLI и зависимости от чужого конфига, организовать приватную установку/поиск плагинов и проверить без системного пакета. Резервные копии документов: `/tmp/opencode/phantom-plugin-source-backup/`.

---

## 2026-11-02 — новая цель: автономность

- По подтверждению пользователя целевая установка должна работать без `caelestia-shell` и `caelestia-cli`. Прежнее решение о постоянных симлинках на пакет отменено; текущие симлинки и установщик остаются только прототипом до переноса.
- В `PROJECT.md` добавлен приоритетный этап 2.5: инвентаризация и перенос QML/ресурсов, сборка или замена C++-модулей, устранение вызовов CLI, собственные настройки и изолированная приёмка без пакетов. После него продолжить интеграцию этапа 3.
- Проверка `pacman -Qo`: `services/Audio.qml` и `Caelestia/Config/libcaelestia-configplugin.so` принадлежат `caelestia-shell 2.5.0-1`. Четыре директории в репозитории — отслеживаемые Git симлинки на пакет. В сервисах обнаружены вызовы CLI `caelestia` (например, `Colours.qml`, `Wallpapers.qml`, `Recorder.qml`); их фактическую достижимость из бара ещё проверить.
- Системные пакеты и сеанс не изменялись; резервные копии документов: `/tmp/opencode/phantom-autonomy-plan-backup/`.

---

## 2026-11-02 — безопасное копирование бара

- `sync.sh`: `config/hypr` исключён из автоматического копирования из HOME, чтобы не перезаписать конфигурацию форка; исключение `caelestia-bar` сохранено. Ранее записанное предупреждение о перезаписи `config/hypr` больше не актуально. Остальные каталоги и скрипты `sync.sh` по-прежнему могут изменяться.
- `install.sh`, `install/lib/phantom-bar.sh`: отдельное копирование файлов порта без следования исходным симлинкам, создание четырёх симлинков на установленную Caelestia, предварительный отказ при отсутствии зависимостей или конфликтах и при симлинках в дереве назначения. Установку зависимостей и переключение автозапуска ещё предстоит реализовать.
- Проверки: `bash -n install.sh install/lib/phantom-bar.sh sync.sh`, `git diff --check`; изолированный тест функции установки с фиктивными каталогами подтвердил копирование, целевые симлинки, отказ при конфликте и защиту от перенаправления копирования. Изолированный тест `sync.sh` подтвердил сохранение бара и `config/hypr`, синхронизацию другого приложения. Текущую сессию, реальный HOME, реальные файлы назначения и установщик не меняли; `shellcheck` не установлен.
- Резервные копии: `/tmp/opencode/phantom-stage3-install-backup/`. Дальше: зависимости, автозапуск нового бара, адаптация скриптов и страницы настроек.

---

## 2026-11-02 — начало этапа 3

- В `PROJECT.md` добавлены замена Waybar-настроек в `rice-settings` (`Super+U`) на настройки нового бара и отдельный отложенный пункт про плавающий бар. Плавающий режим сейчас не реализован.
- `sync.sh`: `caelestia-bar` включён в `SKIP_QS`, чтобы синхронизация не удалила порт и не скопировала содержимое его пакетных симлинков. Тест с отдельными фиктивными HOME и репозиторием: файл бара сохранён, другое приложение Quickshell синхронизировано.
- `config/hypr/hyprland.lua`: добавлены отдельные правила `caelestia-bar-blur` и `caelestia-bar-slide`; Waybar и его запуск пока оставлены до подготовки установки и остальных точек интеграции.
- Проверки: `bash -n sync.sh`, `luac -p config/hypr/hyprland.lua`, `git diff --check`, `hyprctl configerrors` без вывода. Это не проверка новых layer-правил в сессии форка: текущий Hyprland использует другой конфиг. Caelestia не останавливалась, установщик и реальный `sync.sh` не запускались.
- Риск: установочный `copy_tree` использует `find -L` и следует за симлинками бара; его ещё необходимо адаптировать. `sync.sh` также перезаписывает `config/hypr` из HOME, поэтому реальный запуск пока небезопасен для изменений форка. Резервные копии: `/tmp/opencode/phantom-stage3-backup/`.

---

## 2026-11-02 — шеврон трея и порядок значков

- `components/Tray.qml`: смещение шеврона вниз на 2 px без изменения фона; `components/StatusIcons.qml`: раскладка перед микрофоном, противоположно предыдущему решению.
- Бар загружен на eDP-1 и DP-3 (1920×40 и 2560×40); внешний вид и порядок проверены по `/tmp/opencode/phantom-tray-layout-edp.png` и `/tmp/opencode/phantom-tray-layout-dp.png`. Интерактивные проверки не проводились.
- `/tmp/opencode/phantom-tray-layout-test.log`: загрузка без ошибок, прежние предупреждения Qt о потоках и StatusNotifierItem. Caelestia восстановлена; резервные копии: `/tmp/opencode/phantom-tray-layout-backup/`.

---

## 2026-11-02 — проверка бара 40 px

- Caelestia временно остановлена, тестовый бар запущен и визуально проверен; `hyprctl layers`: 1920×40 на eDP-1, 2560×40 на DP-3. Скриншоты: `/tmp/opencode/phantom-40-edp.png`, `/tmp/opencode/phantom-40-dp.png`.
- Визуально: круг трея, уменьшенная подложка рабочего стола, скруглённые группы и цвет часов; клики и попоуты в этом запуске не проверялись.
- Конфиг загрузился. В `/tmp/opencode/phantom-40-test.log` предупреждение об отвергнутой регистрации StatusNotifierItem и предупреждения Qt о потоках; ошибок загрузки нет.
- Тестовый бар остановлен, Caelestia возвращена, `caelestia-drawers` присутствует на обоих мониторах. Резервные копии документов: `/tmp/opencode/phantom-test-40-backup/`.

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

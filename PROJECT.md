# phantom-shell — проект и статус

Дата создания: 2026-11-02
Репозиторий: `/home/rassvet/Projects/phantom-shell` (форк shadows-shell, upstream V2.97, HEAD `4202205`)
Upstream для сверки: `/home/rassvet/Projects/shadows-shell`

---

## 1. Цель

Собственный форк shadows-shell под именем **phantom-shell**: независимое развитие на GitHub с возможностью периодически подтягивать функционал из апстримов (shadows-shell и Caelestia).

Первый крупный шаг — **бар из Caelestia shell (Quickshell) вместо waybar**:

- горизонтальный, сверху;
- полный функционал, включая попоуты (звук, сеть, Bluetooth, батарея, трей-меню, раскладка);
- высота чуть меньше оригинала, настраиваемая (ориентир 34–36 px).
- автономность от `caelestia-shell` и `caelestia-cli`: после их удаления форк должен работать из собственных исходников и обычных системных зависимостей.

---

## 2. Принятые решения

| Вопрос | Решение |
|---|---|
| Ориентация | Горизонтальный бар сверху (не вертикальный справа, как в Caelestia) |
| Функционал | Бар + попоуты |
| Код Caelestia | Решение о симлинках отменено: перенести необходимые исходники и ресурсы в форк или заменить собственными; симлинки допустимы только во временном прототипе |
| Лицензия форка | GPL-3 (Caelestia GPL-3 + shadows MIT → сборка целиком GPL-3) |
| Порядок | Сначала локальная проверка, shadows/waybar не трогаем до подтверждения |

---

## 3. Факты о системе (проверено 2026-11-02)

- ОС: CachyOS, Hyprland **0.57.0**, сессия через `uwsm`.
- Пакеты: `quickshell-git 0.3.2.r11.g9b0f339-1`, `caelestia-shell 2.5.0-1`, `caelestia-cli 1.1.3-1`, `waybar 0.15.0-3.1`.
- **Сейчас активна Caelestia**: процесс `qs -c caelestia -n -d` (pid 1330), layer-namespace `caelestia-*`, конфиг Hyprland — `~/.config/hypr/hyprland.lua` (Caelestia, требует `hyprland/*.lua`, оверрайды `~/.config/caelestia/hypr-user.lua` и `hypr-vars.lua`).
- **waybar сейчас не запущен.**
- Мониторы: `eDP-1` 1920x1080@144, `DP-3` 2560x1440@180 (проверять `hyprctl monitors`).

### Где лежит бар Caelestia

- `/etc/xdg/quickshell/caelestia/modules/bar` — **24 файла, 3170 строк** (пакетный путь, редактировать нельзя).
- Бар **вертикальный, справа, на всю высоту**, эксклюзивная зона справа.
- Состав: `Bar.qml`, `BarWrapper.qml`, `components/{OsIcon,Workspaces,ActiveWindow,Tray,TrayItem,Clock,StatusIcons,Power}`, `components/workspaces/{Workspaces,Workspace,ActiveIndicator,GapMarkers,OccupiedBg,SpecialWorkspaces}`, `components/status/{Battery,Bluetooth,LockStatus}`, `popouts/*` (13 файлов).
- Элементы бара: `logo`, `workspaces`, `activeWindow`, `tray`, `clock`, `statusIcons`, `power`, `spacer` (список в C++ `Config.bar.entries`).

### Зависимости бара

- `qs.services` (17 файлов): Audio, Brightness, Colours, GameMode, Hypr, IdleInhibitor, Nmcli, NotifData, Notifs, Players, Recorder, Screens, ShellState, Time, VPN, Wallpapers, Weather.
- `qs.components` (~40 используемых файлов), `qs.utils` (Icons, Images, NetworkConnection, Paths, Searcher, Strings, SysInfo).
- C++ QML-модули (уже системные): `/usr/lib/qt6/qml/Caelestia/{Config,Components,Services,Settings,I18n,Images,Models,Blobs}`.
  - `Caelestia.Config` даёт `Config`, `GlobalConfig`, `Tokens`, `Appearance`, `M3Palette`.
  - Настройки читаются из `~/.config/caelestia/shell.json`.
- Цвета: `Colours` читает `~/.local/state/caelestia/scheme.json` через `FileView` с `watchChanges: true` → перезагрузка при изменении файла.
- Наивная зависимость бара = **254 из 282 QML-файлов** всего шелла, потому что `popouts/Wrapper.qml` импортирует `qs.modules.nexus` и `qs.modules.windowinfo`. Вывод: нужен **slim-Wrapper** без Nexus/windowinfo.

### Поведение, которое надо сохранить/перепривязать

- `OsIcon` (логотип) → `ShellState.forActive().launcher` → **перепривязать на `hyprlauncher`**.
- `Power` → `screenState.session` → **перепривязать на `~/.local/bin/logout`**.
- `ActiveWindow` → попоут active window (внутри порта).
- Колесо мыши: в Caelestia верхняя половина — громкость, нижняя — яркость; для горизонтального бара — левая/правая половина.
- Скрытие бара при fullscreen — логика в `ContentWindow.qml` (`hasFullscreen`, `Hypr` + `monitor.activeWorkspace.toplevels`).

### Интеграция в shadows-shell (что придётся править)

- `config/hypr/hyprland.lua`:
  - строка ~57: `hl.exec_cmd("waybar")` → запуск нового бара;
  - layer-правила `waybar-blur` (~423) и `waybar-slide` (~454) → namespace нового бара;
  - `gaps_out = 12` (~103) — учесть эксклюзивную зону сверху.
- `bin/`: `waybar-set`, `waybar-reload`, `waybar-autohide`, `waybar-preset`, `rice-effects` (gaming отключает waybar), `rice-colors` (matugen), `rice-ws-watch`, `font-set`, `rice-lock`, `rice-notify`, `rice-dashboard`, `rice-desktop`, `rice-hotcorner`, `ws-go`, `ws-watch`.
- `quickshell/rice-settings/`: `WaybarPage.qml`, `BarLayoutPage.qml`, `shell.qml`, `HomePage.qml` — страницы Waybar станут мёртвыми, скрыть/заменить.
- `install.sh`: строки ~362–369 копируют все каталоги `quickshell/*`, ~436–437 запускают waybar; зависимости пакетов.
- `sync.sh`: `TOOLS`, `CONFIG_DIRS`, `SKIP_QS` — исключить симлинки нового бара из копирования.
- `config/matugen/config.toml` + `config/matugen/templates/*` — добавить шаблон `scheme.json`.
- README/docs, `nix/module.nix`, `flake.nix`.

### Лицензии

- Caelestia — **GPL-3** (`/etc/xdg/quickshell/caelestia/LICENSE`).
- shadows-shell — **MIT** (`/home/rassvet/Projects/shadows-shell/LICENSE`).
- Вендоринг адаптированного бара → распространяемая сборка форка должна быть **GPL-3**; MIT-части сохраняют уведомления; нужен `LICENSE` и attribution Caelestia в README.

---

## 4. Архитектура

```
~/Projects/phantom-shell/
├── PROJECT.md                         # этот файл: цель, решения, статус, план, риски
├── JOURNAL.md                         # append-only журнал выполненного
├── AGENTS.md                          # правила для OpenCode
├── quickshell/caelestia-bar/          # новый quickshell-конфиг, отдельный процесс qs -c caelestia-bar
│   ├── shell.qml                      # PanelWindow на монитор, fullscreen, exclusiveZone
│   ├── config/BarConfig.qml           # singleton: толщина 36, padding 4, команда лаунчера
│   ├── modules/bar/                   # вендоренный модуль Caelestia под горизонталь (GPL-3)
│   ├── components/ services/ utils/ assets/  # симлинки на /etc/xdg/quickshell/caelestia/*
│   ├── LICENSE                        # GPL-3 + копирайт Caelestia
│   └── README.md
├── bin/caelestia-bar                  # start/stop/restart (по образцу bin/rice-desktop)
├── config/hypr/hyprland.lua           # exec нового бара, layer_rule, gaps
├── config/matugen/…                   # шаблон scheme.json + post_hook
└── install.sh / sync.sh               # симлинки, зависимости, исключения
```

`~/Projects/shadows-shell/` — чистый upstream, не редактируется; используется для диффов и переноса фич.

Ключевые принципы:

- Временное состояние прототипа: `services`, `components`, `utils`, `assets` — симлинки на пакет. Это не целевая архитектура; необходимо перенести нужные файлы или заменить их до автономного релиза.
- `modules/bar` — вендорится, потому что его придётся переписывать под горизонталь.
- `popouts/Wrapper.qml` заменяется slim-версией (без `qs.modules.nexus` и `qs.modules.windowinfo`).
- Бар — **отдельный процесс** `qs -c caelestia-bar` (изоляция от `rice-desktop`, независимый рестарт).
- Тема: matugen-шаблон пишет `~/.local/state/caelestia/scheme.json`, `Colours` сам перечитывает.

### Что переделано под горизонталь (факт)

- `Bar.qml`: `RowLayout`, `hPadding`, `checkPopout`/`handleWheel` по X, колесо: левая половина — громкость, правая — яркость.
- `BarWrapper.qml`: горизонтальная полоса, `implicitHeight` = толщина, `exclusiveZone` по высоте, `visible` вместо анимации ширины.
- `Workspaces.qml`: `LazyListView` заменён на `Row` + `Repeater`; логика `wsIds` сохранена.
- `Workspace.qml`: индикатор + иконки окон в строку, активный воркспейс — заливка `m3primary`.
- `ActiveIndicator.qml`, `GapMarkers.qml`, `OccupiedBg.qml`: **удалены**, функциональность свёрнута в `Workspace.qml`.
- `SpecialWorkspaces.qml`: `Row` вместо прокручиваемого списка, клик переключает special.
- `ActiveWindow.qml`: без повёрнутого текста, `elide` по `maxWidth`.
- `Clock.qml`: одна строка `HH:mm` (+ дата/иконка/секунды по конфигу).
- `Tray.qml`: `Row`, компактное раскрытие вправо, `nonAnimWidth`.
- `StatusIcons.qml`, `BluetoothStatus.qml`, `LockStatus.qml`: строки вместо колонок.
- `Power.qml`, `OsIcon.qml`: размеры от `BarConfig.innerThickness`; логотип запускает `BarConfig.launcherCommand`.
- Толщина: `config/BarConfig.qml` (`thickness: 36`, `padding: 4`), вместо `Tokens.sizes.bar.innerWidth` (40).
- `popouts/Wrapper.qml`: slim-версия без `nexus`/`windowinfo`, `Content` + `PopoutState`, `currentCenter` по X, `close()` по Escape.
- `shell.qml`: второе окно `popouts` (fullscreen, `Overlay`, mask), фон `Elevation` + `StyledRect`, позиционирование `x` с clamp, закрытие по уходу курсора (400 мс), `Hypr.activeToplevel`, fullscreen.

### Модуль `modules/drawers` (заглушка)

`components/controls/Menu.qml` импортирует `qs.modules.drawers`, но не использует оттуда типы. В форке создан `modules/drawers/qmldir` с комментарием — предупреждение `Ignoring unresolvable import` ушло. При портировании меню/дроверов заменить реальным модулем.

---

## 5. Этапы

- [x] **−1. Каталоги и клоны.** `/home/rassvet/Projects/shadows-shell` (upstream V2.97), `/home/rassvet/Projects/phantom-shell` (копия, `origin` → `upstream`). Документы созданы.
- [x] **0. Спайк** (15–30 мин). Конфиг в `/tmp/opencode/caelestia-bar`, симлинки, минимальный `shell.qml` с `BarWrapper` (пока вертикальным). Проверить: резолвится ли `qs.*` через симлинки, стартует ли `Caelestia.Config` вне шелла Caelestia, рисуется ли бар, нет ли ошибок в логе. Если симлинки не работают — план Б: вендорить `services`/`components`/`utils`.
- [x] **1. Горизонтальный бар без попоутов.** `BarWrapper` сверху, `RowLayout`, воркспейсы/часы/заголовок/трей/статус в строку, `exclusiveZone` по высоте, скрытие в fullscreen. Проверка на `eDP-1` + `DP-3`, колесо (громкость слева, яркость справа), перезапуск.
  - Сделано 2026-11-02: высота 36 px (`config/BarConfig.qml`), окна `caelestia-bar` 1920x36 и 2560x36, fullscreen скрывает бар только на своём мониторе.
  - Отклонения от плана: `LazyListView` (вертикальный C++-список) заменён на `Row`/`Repeater`; `ActiveIndicator`, `GapMarkers`, `OccupiedBg` удалены, их роль выполняет подсветка в `Workspace.qml`; попоуты — заглушка `popouts/Wrapper.qml` с тем же API.
  - Не проверено вживую: колесо и клики (нет инструмента синтетического ввода).
- [x] **2. Попоуты.** Slim-`Wrapper`, позиционирование под иконкой по X, звук/сеть/BT/батарея/трей-меню/раскладка, hover.
  - Сделано 2026-11-02: отдельное fullscreen-окно `caelestia-popouts` (`WlrLayer.Overlay`, `ExclusionMode.Ignore`, `exclusiveZone: -1`, `mask` по прямоугольнику попоута); собственный фон `Elevation` + `StyledRect` (в Caelestia фон рисуют `PanelBg`-блобы в окне drawers).
  - Закрытие: уход курсора с бара и попоута (таймер 400 мс), смена `Hypr.activeToplevel`, fullscreen, `close()`/Escape внутри wrapper'а.
  - Логотип → `BarConfig.launcherCommand` (`rofi -show drun`). Питание → `BarConfig.powerCommand`, если задан, иначе переключает `screenState.session` (панели сессии пока нет).
  - Проверено вживую: hover по всем иконкам, переключение между иконками, трей-меню (Riff), клик внутри попоута, колесо (громкость/яркость), полный экран. Не проверено: `wirelesspassword` (нужна защищённая сеть) и отсоединённые панели (nexus/windowinfo не портированы).
- [ ] **2.5. Автономность от Caelestia — приоритет перед завершением этапа 3.**
  - Уточнить транзитивные QML, C++, ресурсы и вызовы `caelestia-cli`, зафиксировать версии исходников и лицензии; не менять пакетные файлы.
  - Перенести необходимые QML-компоненты, сервисы, утилиты и ресурсы в репозиторий либо заменить их; исключить ссылки на `/etc/xdg/quickshell/caelestia`.
  - Определить сборку требуемых C++ QML-модулей из исходников в составе форка или заменить их; обеспечить их загрузку и установку без пакета `caelestia-shell` и без конфликтов с системой.
  - Убрать обязательные вызовы `caelestia-cli` и зависимость от пользовательских настроек/схемы Caelestia: собственные настройки, миграция и тема с безопасными значениями по умолчанию.
  - Адаптировать установщик и зависимости; сохранить GPL-3 и уведомления об авторстве, включая исходники и их происхождение.
  - Приёмка: чистая изолированная среда без `caelestia-shell` и `caelestia-cli`, проверка путей загрузки QML/библиотек, запуск из установленной копии, оба монитора, трей, попоуты, ввод пароля, колесо и fullscreen. Не удалять пакеты из основной системы без отдельного подтверждения.
- [ ] **3. Интеграция в shadows.** `exec` вместо waybar, layer-правила `caelestia-bar` (blur), `rice-effects` (gaming), `waybar-*` скрипты отключить/заменить, `rice-settings` (скрыть Waybar/Bar layout), `install.sh`/`sync.sh`, README.
  - В настройках оболочки `rice-settings` (в форке `Super+U`) заменить разделы Waybar / Bar layout настройками нового бара; проверить, что элементы управления действительно применяют изменения к нему. Не оставлять неработающие настройки Waybar как настройки нового бара.
- [ ] **4. Тема.** Шаблон matugen → `~/.local/state/caelestia/scheme.json`, post_hook на перезапуск бара. Проверка: смена обоев → цвета бара совпадают с рисом.
- [ ] **5. Форк и публикация.** `gh repo create phantom-shell`, `origin` → свой репозиторий, `upstream` → `shadowww-dev/shadows-shell`, ветка `feat/caelestia-bar`, GPL-3, отдельная папка бара для безболезненных мержей апстрима.
- [ ] **6. Переключение сессии** (отдельно, с подтверждением). Остановить `qs -c caelestia`, включить shadows' `hyprland.lua`, запустить бар. Откат: `caelestia shell -d`.
- [ ] **В будущем — плавающий бар.** Добавить возможность включить плавающий режим с отступами от краёв и соответствующим поведением эксклюзивной зоны и попоутов; сейчас не реализовывать. Позже предусмотреть управление режимом в настройках нового бара.

---

## 6. Текущий статус

**Сделано:**
- Исследование: бар Caelestia разобран, зависимости и точки интеграции найдены.
- Созданы каталоги и клоны в `/home/rassvet/Projects` (upstream V2.97, HEAD `4202205`).
- Созданы `PROJECT.md`, `JOURNAL.md`, `AGENTS.md`, скилл `phantom-shell`.
- **Этап 0 (спайк) пройден:** симлинки на `/etc/xdg/quickshell/caelestia/{services,components,utils,assets,modules}` работают, `qs.*` резолвится, `Caelestia.Config` стартует вне шелла Caelestia, бар рисуется на обоих мониторах без QML-ошибок.
  - Окна: `caelestia-bar`, 60x1420 на DP-3 (x=4410, y=10) и 60x1060 на eDP-1 (x=1850, y=10).
  - Отступ y=10 — из-за эксклюзивных зон Caelestia (`caelestia-border-exclusion`); в конфиге shadows их не будет.
  - Спайк зарегистрировал StatusNotifierItems — трей на время теста перехватывается, для честных тестов останавливать Caelestia.

- **Этап 2 (попоуты) пройден:** отдельное окно `caelestia-popouts`, slim-`Wrapper` без `nexus`/`windowinfo`, фон попоута, закрытие по уходу курсора/смене фокуса/fullscreen. Проверено hover'ом и кликами (`ydotoold`, временный пользовательский демон, после теста остановлен).
  - Звук, сеть, Bluetooth, батарея, раскладка, трей-меню — работают и позиционируются под своей иконкой с прижатием к краю экрана.
  - `wirelesspassword` не проверен: в окружении нет защищённой сети для теста; для него окно попоутов запрашивает `WlrKeyboardFocus.OnDemand`.
  - Клик по иконкам статуса не открывает/не закрывает попоут (как в Caelestia: открытие по hover).

**Сейчас:** этап 2.5 — подготовка автономности от пакетов Caelestia; этап 3 продолжить после этого. Отдельный бар после тестов остановлен, сессия работает на Caelestia (`caelestia shell -d`); запуск прототипа: `qs -p ~/Projects/phantom-shell/quickshell/caelestia-bar` (предварительно остановить Caelestia).

**Автономность, первые исходники:** в `vendor/caelestia-shell-plugin-v2.5.0/` добавлены неизменённые C++-плагины из Caelestia `v2.5.0` (commit `d999d4878ee4cec134168e60d913714566a8cfa6`) с лицензией и происхождением. Их отдельная сборка в `/tmp/opencode` завершена успешно; загрузка их баром и работа без пакета ещё не проверены. Установленные каталоги `components`, `services`, `utils`, `assets` побайтно совпали с одноимёнными каталогами тега по `diff -qr`. QML/ресурсы пока не перенесены, текущие симлинки и вызовы CLI остались; установщик пока нельзя считать автономным.

**Обновление автономности:** четыре симлинка в `quickshell/caelestia-bar/` заменены локальными неизменёнными каталогами из того же тега; `LICENSE` и `UPSTREAM.md` сохранены рядом. `install/lib/phantom-bar.sh` копирует эти локальные файлы без ссылок на пакет и отказывается писать через симлинки назначения. Существующую старую установку со ссылками нужно будет перенести отдельно с резервной копией; автоматическая миграция пока отсутствует. Плагины ещё не подключены и CLI/настройки ещё зависят от Caelestia, поэтому запуск без пакета не подтверждён.

**Проверка плагинов:** `tests/smoke-caelestia-plugin.sh` проверяет загрузку собранных модулей из каталога сборки в песочнице с закрытым системным каталогом QML Caelestia. Успешно загружены 17 библиотек из сборки; это только smoke-тест импортов, не проверка бара или установки. Приватная установка и подключение плагинов к бару остаются.

**Приватная копия плагинов:** с отдельного подтверждения выполнена тестовая установка в `/tmp/opencode/phantom-plugin-install.UCtGKa`; при скрытом системном QML-каталоге Caelestia все 17 библиотек загружены из неё. Добавлен `bin/phantom-bar`, который выставляет приватные пути для процесса и проверяет наличие модулей и библиотек; его аргументы и отказ при отсутствии модулей проверены с заменой `qs` на тестовую заглушку. Сам бар через этот запускатель ещё не проверен, установщик не собирает/не устанавливает плагины, автозапуск не изменён; автономность пока не достигнута.

**Корректировка 2026-11-02:** по запросу высота изменена с 36 на 60 px, внутренний фон — 40 px; рабочие столы отображаются числами без иконок приложений, заголовок привязан к центру монитора, шеврон трея расположен в круге, микрофон — перед раскладкой. В `config/hypr/hyprland.lua` автозапуск swaync заменён на `systemctl --user start swaync.service`. Предыдущее решение о высоте 36 px отменено. Визуально проверены оба монитора; интерактивная проверка трея и подтверждение снижения нагрузки swaync остаются.

**Новая корректировка:** решение о 60 px отменено: бар 40 px, внутренние подложки 32 px, круг рабочих столов меньше; у трея круг, у групп — скругление радиусом в половину высоты, цвет часов как у значков. Проверено визуально на двух мониторах; после теста Caelestia возвращена. Проверка кликов и попоутов этой версии остаётся.

**Последняя правка:** шеврон трея опущен на 2 px без сдвига фона; раскладка расположена непосредственно перед микрофоном (прежнее решение о микрофоне перед раскладкой отменено). Визуально проверено на двух мониторах, Caelestia возвращена.

**Этап 3 начат:** `sync.sh` исключает `caelestia-bar` из перезаписываемых приложений; в конфиге форка добавлены правила `caelestia-bar-blur` и `caelestia-bar-slide`, старые правила Waybar пока сохранены. Тест `sync.sh` проведён только в изолированном фиктивном HOME и репозитории, текущая сессия не переключалась. Остались безопасная установка симлинков и зависимостей бара, замена автозапуска Waybar, связанные скрипты, новые настройки бара и полноценная проверка. Внимание: `sync.sh` по-прежнему перезаписывает каталог `config/hypr` из домашнего конфига; до адаптации не запускать его на реальном репозитории без проверки последствий.

**Обновление этапа 3:** предупреждение о перезаписи `config/hypr` выше устранено: каталог исключён из автоматической синхронизации. `install.sh` использует `install/lib/phantom-bar.sh`: копирует файлы бара без следования симлинкам и создаёт четыре ссылки на установленную Caelestia, отказываясь заменять конфликтующие пути. Проверены изолированные тесты; реальная установка и запуск в сессии форка не проверены. Зависимости бара пока не добавлены в установку пакетов. `sync.sh` остаётся скриптом синхронизации других пользовательских файлов и всё ещё может их перезаписать — перед реальным запуском проверить полный список его действий.

**Дальше:** инвентаризация транзитивных зависимостей и источников плагинов, перенос в форк, изолированная проверка без Caelestia; затем продолжить интеграцию Waybar → бар, настройки, `install.sh`/`sync.sh` и README.

---

## 7. Риски и ограничения

- Жёсткая зависимость от пакета `caelestia-shell` (C++ `Config`/`Tokens`/`M3Palette`). Обновление пакета может сломать вендоренный модуль — обновлять вручную.
- Настройки бара (`Config.bar.*`) живут в `~/.config/caelestia/shell.json`, а UI для них — Caelestia Nexus, которого в порте не будет. Варианты: править JSON руками или позже сделать страницу в `rice-settings`.
- Два шелла одновременно не уживутся: SystemTray-хост один. Для честного теста надо на время остановить `qs -c caelestia` — уведомления и обои на эти минуты пропадут (вернуть: `caelestia shell -d`).
- Попоуты завязаны на `Nmcli`, `Audio`, `Brightness`, `Players` — на shadows' Hyprland работают через IPC, но проверять на живом сеансе.
- Нельзя редактировать `/etc/xdg/quickshell/caelestia/**` (пакет).
- Перед правками конфигов — резервные копии; после правок Lua/JSON — валидация и `hyprctl configerrors`.

---

## 8. Полезные команды

```bash
# состояние
hyprctl monitors
hyprctl configerrors
pgrep -af 'qs -c|waybar'
qs --version
pacman -Q caelestia-shell quickshell-git waybar

# запуск/остановка Caelestia shell
qs -c caelestia -n -d
caelestia shell -d
pkill -f 'qs -c caelestia'

# новый бар (после этапа 0)
qs -c caelestia-bar -n -d

# проверка слоёв
hyprctl layers

# git
git -C ~/Projects/phantom-shell status
git -C ~/Projects/phantom-shell log --oneline -5
```

### Git и откат

Ветки: `main` — базовая линия (upstream + документы), `feat/caelestia-bar` — вся работа по бару.
Тег `upstream-2.97` — чистый upstream (commit `4202205`).

```bash
# откатить незакоммиченные правки
git -C ~/Projects/phantom-shell checkout -- .

# откатить всё до последнего коммита на ветке (удаляет и новые файлы)
git -C ~/Projects/phantom-shell reset --hard HEAD
git -C ~/Projects/phantom-shell clean -fd quickshell/caelestia-bar

# посмотреть, что изменено
git -C ~/Projects/phantom-shell status
git -C ~/Projects/phantom-shell diff

# вернуться к базовой линии (документы, без бара)
git -C ~/Projects/phantom-shell checkout main

# вернуться к чистому upstream
git -C ~/Projects/phantom-shell checkout upstream-2.97

# вернуться к работе над баром
git -C ~/Projects/phantom-shell checkout feat/caelestia-bar
```

Коммиты делаются по этапам: один этап — один коммит, чтобы откат был точечным.
Публикация на GitHub — позже (`gh` пока не установлен).

---

## 9. Документация и передача контекста

- `PROJECT.md` (этот файл) — читается в начале каждой сессии.
- `JOURNAL.md` — append-only журнал: дата, что сделано, файлы, проверки, проблемы.
- `AGENTS.md` — правила для OpenCode в каталоге проекта.
- Скилл `~/.config/opencode/skills/phantom-shell/SKILL.md` — триггер по упоминанию шелла из любого каталога.

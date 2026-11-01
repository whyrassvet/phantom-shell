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

---

## 2. Принятые решения

| Вопрос | Решение |
|---|---|
| Ориентация | Горизонтальный бар сверху (не вертикальный справа, как в Caelestia) |
| Функционал | Бар + попоуты |
| Код Caelestia | Вендорить `modules/bar` в форк, остальное — симлинки на установленный пакет |
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
│   ├── shell.qml                      # glue: PanelWindow на монитор, hover/wheel, fullscreen
│   ├── modules/bar/                   # вендоренный модуль Caelestia под горизонталь (GPL-3)
│   ├── LICENSE                        # GPL-3 + копирайт Caelestia
│   └── README.md
├── bin/caelestia-bar                  # start/stop/restart (по образцу bin/rice-desktop)
├── config/hypr/hyprland.lua           # exec нового бара, layer_rule, gaps
├── config/matugen/…                   # шаблон scheme.json + post_hook
└── install.sh / sync.sh               # симлинки, зависимости, исключения
```

`~/Projects/shadows-shell/` — чистый upstream, не редактируется; используется для диффов и переноса фич.

Ключевые принципы:

- `services`, `components`, `utils`, `assets` **не копируются** — симлинки на `/etc/xdg/quickshell/caelestia/*`, создаются установщиком.
- `modules/bar` — вендорится, потому что его придётся переписывать под горизонталь.
- `popouts/Wrapper.qml` заменяется slim-версией (без `qs.modules.nexus` и `qs.modules.windowinfo`).
- Бар — **отдельный процесс** `qs -c caelestia-bar` (изоляция от `rice-desktop`, независимый рестарт).
- Тема: matugen-шаблон пишет `~/.local/state/caelestia/scheme.json`, `Colours` сам перечитывает.

### План переделки под горизонталь (~19 файлов)

- `Bar.qml`: `ColumnLayout` → `RowLayout`, отступы по краям, `vPadding` → `hPadding`.
- `BarWrapper.qml`: вертикальная полоса → горизонтальная, анимация `implicitWidth` → `implicitHeight`, `exclusiveZone` по высоте.
- `Workspaces.qml`: `ListView` → `orientation: Horizontal`, `layoutHeight` → `layoutWidth`.
- `Workspace.qml`: `ColumnLayout` → `RowLayout`, индикатор + иконки окон в строку.
- `ActiveIndicator.qml`, `GapMarkers.qml`, `OccupiedBg.qml`, `SpecialWorkspaces.qml`: геометрия X/Y.
- `ActiveWindow.qml`: убрать повёрнутый текст, горизонтальный заголовок с `elide`, ограничение по ширине.
- `Clock.qml`: одна строка `HH:MM` (+ дата/иконка по конфигу) вместо стопки.
- `Tray.qml` / `TrayItem.qml`: `Column` → `Row`, компактное раскрытие вправо.
- `StatusIcons.qml`: колонка → строка.
- `Power.qml`, `OsIcon.qml`: правки размеров + перепривязка действий.
- `popouts/Wrapper.qml` (slim), `ClipWrapper.qml`, `Content.qml`: позиционирование по X (под иконкой), `currentCenter` меняет смысл Y → X.
- Высота: заменить `Tokens.sizes.bar.innerWidth` (7 использований) на свой параметр `Bar.height` (34–36 px, в конфиг).

---

## 5. Этапы

- [x] **−1. Каталоги и клоны.** `/home/rassvet/Projects/shadows-shell` (upstream V2.97), `/home/rassvet/Projects/phantom-shell` (копия, `origin` → `upstream`). Документы созданы.
- [x] **0. Спайк** (15–30 мин). Конфиг в `/tmp/opencode/caelestia-bar`, симлинки, минимальный `shell.qml` с `BarWrapper` (пока вертикальным). Проверить: резолвится ли `qs.*` через симлинки, стартует ли `Caelestia.Config` вне шелла Caelestia, рисуется ли бар, нет ли ошибок в логе. Если симлинки не работают — план Б: вендорить `services`/`components`/`utils`.
- [ ] **1. Горизонтальный бар без попоутов.** `BarWrapper` сверху, `RowLayout`, воркспейсы/часы/заголовок/трей/статус в строку, `exclusiveZone` по высоте, скрытие в fullscreen. Проверка на `eDP-1` + `DP-3`, колесо (громкость слева, яркость справа), перезапуск.
- [ ] **2. Попоуты.** Slim-`Wrapper`, позиционирование под иконкой по X, звук/сеть/BT/батарея/трей-меню/раскладка, hover. Логотип → `hyprlauncher`, питание → `~/.local/bin/logout`.
- [ ] **3. Интеграция в shadows.** `exec` вместо waybar, layer-правила `caelestia-bar` (blur), `rice-effects` (gaming), `waybar-*` скрипты отключить/заменить, `rice-settings` (скрыть Waybar/Bar layout), `install.sh`/`sync.sh`, README.
- [ ] **4. Тема.** Шаблон matugen → `~/.local/state/caelestia/scheme.json`, post_hook на перезапуск бара. Проверка: смена обоев → цвета бара совпадают с рисом.
- [ ] **5. Форк и публикация.** `gh repo create phantom-shell`, `origin` → свой репозиторий, `upstream` → `shadowww-dev/shadows-shell`, ветка `feat/caelestia-bar`, GPL-3, отдельная папка бара для безболезненных мержей апстрима.
- [ ] **6. Переключение сессии** (отдельно, с подтверждением). Остановить `qs -c caelestia`, включить shadows' `hyprland.lua`, запустить бар. Откат: `caelestia shell -d`.

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

**Сейчас:** этап 1 — горизонтальный бар без попоутов.

**Дальше:** этап 2 (попоуты).

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

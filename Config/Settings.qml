pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Single source of truth for user configuration.
 *
 * The file lives at ~/.config/bw77-shell/settings.json and is watched, so editing
 * it by hand and saving applies instantly. The Control Center writes to the same
 * adapter, so GUI edits and hand edits round-trip through one schema.
 *
 * Anything you add here becomes settable from both places for free.
 */
Singleton {
    id: root

    readonly property string configDir: `${Quickshell.env("HOME")}/.config/bw77-shell`
    readonly property string configPath: `${configDir}/settings.json`

    // Convenience aliases so call sites read as Settings.bar.height, not
    // Settings.data.bar.height.
    readonly property alias bar: adapter.bar
    readonly property alias theme: adapter.theme
    readonly property alias desktop: adapter.desktop
    readonly property alias dock: adapter.dock
    readonly property alias launcher: adapter.launcher
    readonly property alias notifications: adapter.notifications
    readonly property alias clock: adapter.clock
    readonly property alias osd: adapter.osd
    readonly property alias emoji: adapter.emoji
    readonly property alias quickSettings: adapter.quickSettings
    readonly property alias audio: adapter.audio
    readonly property alias animations: adapter.animations
    readonly property alias borders: adapter.borders
    readonly property alias wallpaper: adapter.wallpaper
    readonly property alias lock: adapter.lock
    readonly property alias appTheming: adapter.appTheming
    readonly property alias fx: adapter.fx
    readonly property alias decoration: adapter.decoration
    readonly property alias polkit: adapter.polkit
    readonly property alias general: adapter.general

    property bool loaded: false


    /*
     * --- interface translations
     *
     * Keyed by the English source string rather than by symbolic ids. That
     * makes every call site readable on its own, means a missing entry shows
     * the English rather than a raw key, and avoids maintaining a parallel list
     * of names that drift from the text they stand for.
     *
     * Lives here rather than in a file of its own so that no new QML type has
     * to resolve for the shell to start, and so every file that already imports
     * qs.Config can call it without a new import.
     *
     * t() reads `general.language` on every call, which is what makes bindings
     * that use it re-evaluate when the language changes - switching is instant,
     * with no reload.
     */
    readonly property var translations: ({
        "ru": ({
        "0 fills the space left by the side margins": "0 занимает всё место, оставшееся от боковых отступов",
        "About": "О программе",
        "Accent": "Акцент",
        "Accents": "Акценты",
        "Act as the polkit agent": "Работать агентом polkit",
        "Active": "Активен",
        "Add a widget": "Добавить виджет",
        "Add an application": "Добавить приложение",
        "Adds anything running that is not pinned": "Показывать запущенные приложения без закрепления",
        "Alignment": "Выравнивание",
        "Always": "Всегда",
        "An application": "Приложение",
        "and others are holding this profile": "и другие удерживают этот профиль",
        "Anything without a translation stays in English": "Всё без перевода остаётся на английском",
        "Always keeps them visible at reduced opacity and goes solid on hover": "Всегда видимы с пониженной непрозрачностью, при наведении становятся сплошными",
        "Always visible": "Всегда видима",
        "Always visible reserves screen space; the others reveal on a hot edge": "«Всегда видима» резервирует место на экране; остальные появляются у горячего края",
        "Angle": "Угол",
        "Animation": "Анимация",
        "Animations": "Анимации",
        "App and title": "Приложение и заголовок",
        "App icon": "Значок приложения",
        "App only": "Только приложение",
        "App theming": "Темы приложений",
        "Appearance": "Внешний вид",
        "Application icons": "Значки приложений",
        "Application actions": "Действия приложения",
        "Balanced": "Сбалансированный",
        "held": "удерживается",
        "holding this profile": "удерживает этот профиль",
        "Performance": "Производительность",
        "Power profile": "Профиль питания",
        "Power saver": "Энергосбережение",
        "power-profiles-daemon is not responding": "power-profiles-daemon не отвечает",
        "Show the extra entry points an app declares, in the right-click menu": "Показывать в контекстном меню дополнительные точки входа, заявленные приложением",
        "Applications": "Приложения",
        "Applied per playback, so it does not touch your system volume": "Применяется к каждому воспроизведению и не меняет системную громкость",
        "Apply": "Применить",
        "Arc": "Дуга",
        "Attached": "Прикреплённая",
        "Attached sits flush against the screen edge, detached is a block with its own frame, and floating drops the frame to leave only the widgets": "Прикреплённая примыкает к краю экрана, отдельная — блок со своей рамкой, плавающая убирает рамку и оставляет только виджеты",
        "Audio": "Звук",
        "Audio visualiser": "Визуализатор звука",
        "Authenticate": "Аутентификация",
        "Authenticate as": "Войти как",
        "Authentication agent": "Агент аутентификации",
        "Authentication required": "Требуется аутентификация",
        "Autohide": "Автоскрытие",
        "Available": "Доступно",
        "Backdrop blur": "Размытие подложки",
        "Backdrop brightness": "Яркость подложки",
        "Backdrop surface": "Поверхность подложки",
        "Build it only in the overview": "Создавать только в обзоре",
        "Background opacity": "Непрозрачность фона",
        "Band count and frame rate": "Полосы и частота кадров",
        "Bands": "Полосы",
        "Bar": "Панель",
        "Bar hover": "Наведение на панель",
        "Base palette, per-role overrides and typography": "Базовая палитра, переопределения ролей и шрифты",
        "Base text size": "Базовый размер текста",
        "Behaviour": "Поведение",
        "Below 1 keeps some of each icon's own colour": "Меньше 1 сохраняет часть собственного цвета значка",
        "Block width": "Ширина блока",
        "Blue": "Синий",
        "Bluetooth": "Bluetooth",
        "Body": "Основной",
        "Bold labels": "Жирные подписи",
        "Border": "Рамка",
        "Border colours and width for your compositor": "Цвета и толщина рамок для вашего композитора",
        "Border width": "Толщина рамки",
        "Bottom": "Снизу",
        "Bottom centre": "Снизу по центру",
        "Bottom left": "Снизу слева",
        "Bottom right": "Снизу справа",
        "Detached": "Отдельная",
        "Dividers": "Разделители",
        "Brightness": "Яркость",
        "Brightness slider": "Ползунок яркости",
        "Browse": "Обзор",
        "Calendar": "Календарь",
        "Cancel": "Отмена",
        "Categories": "Категории",
        "Category": "Категория",
        "Center": "По центру",
        "Change": "Изменить",
        "Changes save as you make them": "Изменения сохраняются автоматически",
        "Clear all": "Очистить всё",
        "Clear history": "Очистить историю",
        "Click action": "Действие по клику",
        "Clock": "Часы",
        "Clock, readouts, and anything with a number in it. Use a Nerd Font here or icons will not render.": "Часы, показания и всё, где есть цифры. Используйте Nerd Font, иначе значки не отрисуются.",
        "Close": "Закрыть",
        "Close all": "Закрыть всё",
        "Colour": "Цвет",
        "Colour vibrance": "Насыщенность цвета",
        "Colours": "Цвета",
        "Confirm": "Подтвердить",
        "Control Center": "Центр управления",
        "Corner brackets": "Угловые скобки",
        "Corner cut": "Срез угла",
        "Corner radius": "Радиус скругления",
        "Crimson": "Багровый",
        "Critical sound file": "Звук для важных уведомлений",
        "Custom templates": "Свои шаблоны",
        "Cyberpunk motion snaps rather than eases; speed scales every duration": "Движение в стиле Cyberpunk резкое, без плавности; скорость масштабирует все длительности",
        "Cycle walks through an application's windows on repeated clicks": "Перебор переключает окна приложения при повторных нажатиях",
        "Cycle windows": "Перебирать окна",
        "DISK": "ДИСК",
        "Darkens everything behind the panel while it is open": "Затемняет всё позади панели, пока она открыта",
        "Date format": "Формат даты",
        "Decode animation": "Анимация декодирования",
        "Default": "По умолчанию",
        "Derive the accent colours from the current wallpaper instead of the palette file": "Брать акцентные цвета из текущих обоев вместо файла палитры",
        "Desktop": "Рабочий стол",
        "Desktop edit mode": "Режим правки рабочего стола",
        "Desktop widgets": "Виджеты рабочего стола",
        "Dim": "Затемнение",
        "Dim the desktop": "Затемнять рабочий стол",
        "Disk": "Диск",
        "Display": "Заголовочный",
        "Display is used for headings, body for labels, mono for data": "Заголовочный — для заголовков, основной — для подписей, моноширинный — для данных",
        "Do not disturb": "Не беспокоить",
        "Dock": "Док",
        "Done": "Готово",
        "Down": "Приём",
        "Drag to move, pull the corner to resize": "Перетащите, чтобы переместить; потяните за угол, чтобы изменить размер",
        "Drag widgets between sections to move them, click to configure": "Перетаскивайте виджеты между разделами, нажмите для настройки",
        "Edge margin": "Отступ от края",
        "Edge padding": "Отступ у края",
        "Edit mode": "Режим правки",
        "Effects": "Эффекты",
        "Enable app theming": "Включить темы приложений",
        "English": "English",
        "Entries shown": "Показано записей",
        "Everything currently running is already pinned.": "Всё запущенное уже закреплено.",
        "Fade length": "Длина затухания",
        "Fake machine identifiers printed on panels": "Вымышленные машинные идентификаторы на панелях",
        "First": "Первое",
        "Flatpak apps": "Приложения Flatpak",
        "Floating": "Плавающая",
        "Focus first": "Фокус на первом",
        "Focused application colour": "Цвет активного приложения",
        "Focused, to": "Активное, до",
        "Follow wallpaper": "Следовать обоям",
        "Fonts": "Шрифты",
        "Forces every icon to one palette colour, so a dock of mismatched brand colours reads as one piece": "Приводит все значки к одному цвету палитры, чтобы док из разнородных фирменных цветов смотрелся целостно",
        "Forces every tray icon to a single colour from the palette": "Приводит все значки трея к одному цвету палитры",
        "From": "От",
        "Frame decoration": "Оформление рамки",
        "Frame rate": "Частота кадров",
        "Gap between the screen edge and the dock": "Промежуток между краем экрана и доком",
        "Gap between widgets": "Промежуток между виджетами",
        "Glitch": "Глитч",
        "Slide": "Сдвиг",
        "Fade": "Затухание",
        "Gold": "Золотой",
        "Gradient": "Градиент",
        "Gradient angle": "Угол градиента",
        "Green": "Зелёный",
        "Group by application": "Группировать по приложению",
        "Handles the password prompt for privileged actions": "Обрабатывает запрос пароля для привилегированных действий",
        "Headings and titles": "Заголовки и названия",
        "Height": "Высота",
        "Hex": "Hex",
        "Hidden sources": "Скрытые источники",
        "Hide": "Скрыть",
        "Hide delay": "Задержка скрытия",
        "Hide individual controls without turning off a whole section": "Скрывайте отдельные элементы, не отключая весь раздел",
        "Hide mode": "Режим скрытия",
        "Hiding": "Скрытие",
        "Hold everything except critical alerts": "Задерживать всё, кроме важных оповещений",
        "Horizontal": "Горизонтально",
        "Horizontal CRT lines over panels and the desktop": "Горизонтальные линии ЭЛТ поверх панелей и рабочего стола",
        "Hot edge size": "Размер горячего края",
        "Hovering always goes fully opaque": "При наведении всегда полностью непрозрачно",
        "How far the rule fades in from each end": "Насколько линия затухает с каждого конца",
        "How many neighbours rise with the hovered icon": "Сколько соседей поднимается вместе со значком под курсором",
        "How much of the dock stays on screen to catch the cursor": "Какая часть дока остаётся на экране, чтобы поймать курсор",
        "Hue": "Тон",
        "Hue, saturation, value": "Тон, насыщенность, яркость",
        "Hyprland only; niri corner rounding is set in your own config": "Только для Hyprland; скругление углов в niri задаётся в вашем конфиге",
        "Icon": "Значок",
        "Icon colour": "Цвет значков",
        "Icon outlines": "Контуры значков",
        "Icon scale": "Масштаб значков",
        "Icon size": "Размер значков",
        "Icon spacing": "Отступ между значками",
        "Icons": "Значки",
        "Icons and indicators": "Значки и индикаторы",
        "Image": "Изображение",
        "Individual effects": "Отдельные эффекты",
        "Input device": "Устройство ввода",
        "Input volume": "Громкость ввода",
        "Inset from each end of the edge": "Отступ с каждого конца края",
        "Install brightnessctl to change this": "Установите brightnessctl, чтобы менять это",
        "Interface language": "Язык интерфейса",
        "Interface scale": "Масштаб интерфейса",
        "Join": "Подключиться",
        "Keep clear of the bar": "Не перекрывать панель",
        "Keep other applications in step with the shell palette": "Держать другие приложения в одной палитре с оболочкой",
        "Keeps it at the bottom of the panel instead of scrolling with history": "Держит его внизу панели, а не прокручивает вместе с историей",
        "Keybinds to set in your compositor": "Сочетания клавиш для композитора",
        "Keyboard icon": "Значок клавиатуры",
        "Labels": "Подписи",
        "Labels and most interface text": "Подписи и большая часть текста интерфейса",
        "Language": "Язык",
        "Last": "Последнее",
        "Launch": "Запустить",
        "Launcher": "Меню приложений",
        "Launcher button": "Кнопка меню приложений",
        "Launcher position": "Положение кнопки запуска",
        "Layout": "Раскладка",
        "Leave the focused app in colour": "Оставлять активное приложение цветным",
        "Left": "Слева",
        "Lifts the icon under the cursor and its neighbours": "Приподнимает значок под курсором и его соседей",
        "Line": "Линия",
        "Lock": "Заблокировать",
        "Log out": "Выйти",
        "Looking for input devices\\u2026": "Поиск устройств ввода\\u2026",
        "Looking for output devices\\u2026": "Поиск устройств вывода\\u2026",
        "MEM": "ПАМ",
        "MIC": "МИК",
        "Magnification": "Увеличение",
        "Magnification spread": "Радиус увеличения",
        "Magnify on hover": "Увеличивать при наведении",
        "Manage window borders": "Управлять рамками окон",
        "Marks the application whose window currently has focus": "Отмечает приложение, окно которого сейчас в фокусе",
        "Maximum on screen": "Максимум на экране",
        "Maximum width": "Максимальная ширина",
        "Media": "Медиа",
        "Menus": "Меню",
        "Memory": "Память",
        "Meter": "Индикатор",
        "Meters": "Индикаторы",
        "Microphone is muted or unmuted": "Микрофон включён или выключен",
        "Microphone slider": "Ползунок микрофона",
        "Monospace": "Моноширинный",
        "Move": "Переместить",
        "Mute microphone": "Выключить микрофон",
        "Mute output": "Выключить звук",
        "NET": "СЕТЬ",
        "Name to hide, e.g. cava": "Имя для скрытия, например cava",
        "Network": "Сеть",
        "Network rates": "Скорость сети",
        "Never": "Никогда",
        "No images in that folder": "В этой папке нет изображений",
        "No readable GPU on this machine": "В этой системе нет доступного GPU",
        "No matches": "Совпадений нет",
        "No menu": "Нет меню",
        "No signal": "Нет сигнала",
        "None": "Нет",
        "Normal sound file": "Обычный звуковой файл",
        "Nothing connected": "Ничего не подключено",
        "Nothing here": "Здесь пусто",
        "Nothing selected": "Ничего не выбрано",
        "Nothing is playing right now": "Сейчас ничего не воспроизводится",
        "Nothing playing": "Ничего не воспроизводится",
        "Notification entry": "Появление уведомления",
        "Notification history": "История уведомлений",
        "Notifications": "Уведомления",
        "Now": "Стало",
        "Now playing": "Сейчас играет",
        "OUT": "ВЫХ",
        "Off uses a single colour for the focused border": "При выключении для активной рамки используется один цвет",
        "Off uses the application's own Qt or GTK menu, which will not match the shell": "При выключении используется собственное меню Qt или GTK приложения, которое не совпадёт с оболочкой",
        "Offsets toasts by the bar height so they do not overlap it": "Сдвигает уведомления на высоту панели, чтобы они её не перекрывали",
        "On hover": "При наведении",
        "On-screen display": "Экранные подсказки",
        "Open Desktop": "Открыть «Рабочий стол»",
        "Open bluetooth settings": "Открыть настройки Bluetooth",
        "Open network settings": "Открыть настройки сети",
        "Open new window": "Открыть новое окно",
        "Opens the application launcher, same as the bar button": "Открывает меню приложений, как и кнопка на панели",
        "Order here is the order on the panel": "Порядок здесь — это порядок на панели",
        "Outline": "Контур",
        "Outline resting opacity": "Непрозрачность контура в покое",
        "Output device": "Устройство вывода",
        "Output is muted or unmuted": "Звук включён или выключен",
        "Output volume": "Громкость вывода",
        "Overrides everything below and disables all animation": "Переопределяет всё ниже и отключает все анимации",
        "Overview": "Обзор",
        "Padding": "Внутренний отступ",
        "Padding inside widgets": "Отступ внутри виджетов",
        "Paired": "Сопряжено",
        "Palette": "Палитра",
        "Password": "Пароль",
        "Percentage": "Проценты",
        "Pin the calendar": "Закрепить календарь",
        "Pinned and running applications": "Закреплённые и запущенные приложения",
        "Pinned applications": "Закреплённые приложения",
        "Placed widgets": "Размещённые виджеты",
        "Placement, timing and sound": "Размещение, время и звук",
        "Play a sound": "Воспроизводить звук",
        "Player": "Проигрыватель",
        "Playing": "Воспроизведение",
        "Position": "Положение",
        "Preview": "Предпросмотр",
        "Put the device in pairing mode, then press SCAN": "Переведите устройство в режим сопряжения и нажмите SCAN",
        "Quick actions": "Быстрые действия",
        "Quick settings": "Быстрые настройки",
        "Rail width": "Ширина боковой панели",
        "Random": "Случайно",
        "Random wallpaper": "Случайные обои",
        "Recolour icons": "Перекрашивать значки",
        "Recolour open terminals": "Перекрашивать открытые терминалы",
        "Recolour strength": "Сила перекраски",
        "Red": "Красный",
        "Red and cyan ghosts offset behind text": "Красные и голубые тени со смещением за текстом",
        "Red, green, blue": "Красный, зелёный, синий",
        "Reduce motion": "Уменьшить анимацию",
        "Regular": "Обычный",
        "Remove": "Удалить",
        "Reading GPU...": "Чтение GPU...",
        "Rescan": "Пересканировать",
        "Reserve space": "Резервировать место",
        "Reset": "Сбросить",
        "Reset overrides": "Сбросить переопределения",
        "Restart": "Перезагрузка",
        "Resting opacity": "Непрозрачность в покое",
        "Results shown": "Показано результатов",
        "Right": "Справа",
        "Right-click any dock icon to pin or unpin it": "Нажмите правой кнопкой по значку дока, чтобы закрепить или открепить его",
        "Roman": "Прямой",
        "Running indicators": "Индикаторы запуска",
        "Russian": "Русский",
        "Saturation": "Насыщенность",
        "Scales every size in the shell at once, including this window": "Масштабирует все размеры в оболочке сразу, включая это окно",
        "Scanline strength": "Сила строк развёртки",
        "Scanning...": "Сканирование...",
        "Scanlines": "Строки развёртки",
        "Scroll to switch": "Прокрутка для переключения",
        "Search applications": "Поиск приложений",
        "Seconds on the clock": "Секунды на часах",
        "Sections": "Разделы",
        "Select": "Выбрать",
        "Serial numbers": "Серийные номера",
        "Set the files below; leave empty for silent notifications": "Задайте файлы ниже; оставьте пустым для беззвучных уведомлений",
        "Sets the PipeWire default; applications follow it": "Задаёт устройство PipeWire по умолчанию; приложения следуют за ним",
        "Several messages from one app collapse into a single stacked entry": "Несколько сообщений одного приложения складываются в одну запись",
        "Shared by the top bar, quick settings panel and dock": "Общее для верхней панели, быстрых настроек и дока",
        "Show": "Показывать",
        "Show categories": "Показывать категории",
        "Show date": "Показывать дату",
        "Show desktop widgets": "Показывать виджеты рабочего стола",
        "Show it when": "Показывать при",
        "Show outlines": "Показывать контуры",
        "Show percentage": "Показывать проценты",
        "Show running applications": "Показывать запущенные приложения",
        "Show the OSD": "Показывать подсказки",
        "Show the dock": "Показывать док",
        "Shut down": "Выключить",
        "Side": "Сторона",
        "Side margin": "Боковой отступ",
        "Size": "Размер",
        "Size, layout and how categories are shown": "Размер, раскладка и отображение категорий",
        "Sliders": "Ползунки",
        "Small L-marks at the corners of framed content": "Небольшие уголки по краям рамок",
        "Snap to grid": "Привязка к сетке",
        "Solid": "Сплошная",
        "Sound": "Звук",
        "Source": "Источник",
        "Space between the screen edge and the first widget": "Расстояние от края экрана до первого виджета",
        "Speed": "Скорость",
        "Status": "Состояние",
        "Stored history": "Хранимая история",
        "Style": "Стиль",
        "Substring match on an application or node name": "Поиск подстроки в имени приложения или узла",
        "Surface open": "Открытие поверхности",
        "Surfaces": "Поверхности",
        "Suspend": "Спящий режим",
        "System": "Система",
        "TEMP": "ТЕМП",
        "Throttled: high temperature": "Ограничено: высокая температура",
        "Throttled: lap detected": "Ограничено: обнаружены колени",
        "TMP": "ТМП",
        "Temp": "Темп.",
        "Temperature": "Температура",
        "Templates are rendered whenever the palette changes": "Шаблоны перегенерируются при каждом изменении палитры",
        "Test": "Проверка",
        "Text": "Текст",
        "Text colour": "Цвет текста",
        "Frame colour": "Цвет рамки",
        "Text decode": "Декодирование текста",
        "Text scrambles before settling when a value changes": "Текст перемешивается и собирается заново при изменении значения",
        "Text weight": "Насыщенность текста",
        "Text size": "Размер текста",
        "The application with focus keeps its own icon, as a second focus cue": "Приложение в фокусе сохраняет свой значок как дополнительный признак фокуса",
        "The input level slider under the volume section": "Ползунок уровня входа под разделом громкости",
        "The overlay shown when volume or mute changes": "Оверлей при изменении громкости или отключении звука",
        "The parts that make it feel like a screen inside the game": "То, что делает это похожим на экран из игры",
        "The side panel opened from the bar or by keybind": "Боковая панель, открываемая с панели или по сочетанию клавиш",
        "The single most expensive widget to run": "Самый ресурсоёмкий виджет",
        "The spectrum widget is configured with the desktop widgets": "Виджет спектра настраивается вместе с виджетами рабочего стола",
        "Theme": "Тема",
        "This GPU reports no metrics": "Этот GPU не сообщает метрик",
        "Theme colour": "Цвет темы",
        "Themed tray menus": "Меню трея в теме",
        "These belong to the desktop audio widget, so they live with it": "Они относятся к звуковому виджету рабочего стола и настраиваются вместе с ним",
        "Thickness": "Толщина",
        "This display only": "Только этот дисплей",
        "Throughput across all interfaces": "Пропускная способность по всем интерфейсам",
        "Time format": "Формат времени",
        "Time on screen": "Время на экране",
        "Timeout": "Таймаут",
        "Title only": "Только заголовок",
        "To": "До",
        "Tooltips": "Подсказки",
        "Top": "Сверху",
        "Top bar": "Верхняя панель",
        "Top centre": "Сверху по центру",
        "Top left": "Сверху слева",
        "Top right": "Сверху справа",
        "Transfer rates": "Скорость передачи",
        "Enter edit mode": "Войти в режим правки",
        "Every widget on the bar. Zero follows the base text size from Theme": "Все виджеты панели. Ноль — базовый размер текста из темы",
        "Unknown": "Неизвестно",
        "Workspace numbers stay a step heavier than this": "Номера рабочих столов остаются на шаг жирнее",
        "Text vertical trim": "Вертикальная подгонка текста",
        "Text is centred on its capitals automatically; nudge it if your font still sits high or low": "Текст автоматически центрируется по заглавным буквам; сместите его, если шрифт всё ещё стоит выше или ниже нужного",
        "Tray": "Трей",
        "Tray icons ship at inconsistent sizes; this forces them all to match": "Значки трея приходят разного размера; это приводит их к одному",
        "Try a shorter search, or press Tab to change category": "Попробуйте более короткий запрос или нажмите Tab, чтобы сменить категорию",
        "Turn on edit mode, then drag widgets and pull the corner to resize": "Включите режим правки, затем перетаскивайте виджеты и тяните за угол для изменения размера",
        "Typography": "Шрифты",
        "Unfocused": "Неактивное",
        "Up": "Передача",
        "Urgent": "Важное",
        "Value": "Яркость",
        "Vertical": "Вертикально",
        "Vertical is a rail down the left; horizontal is an icon strip above the results": "Вертикально — полоса слева; горизонтально — лента значков над результатами",
        "Visualiser": "Визуализатор",
        "Volume": "Громкость",
        "Volume changes": "Изменение громкости",
        "Wallpaper": "Обои",
        "Wallpaper in the niri overview": "Обои в обзоре niri",
        "Wallpaper transition": "Переход обоев",
        "Was": "Было",
        "Widget outlines": "Контуры виджетов",
        "Widgets become draggable and the alignment grid appears. The Control Center closes so you can reach them.": "Виджеты можно перетаскивать, появляется сетка выравнивания. Центр управления закроется, чтобы вы могли до них добраться.",
        "Widget spacing": "Отступы виджетов",
        "Width": "Ширина",
        "Windows": "Окна",
        "Windows avoid the bar instead of drawing underneath it": "Окна обходят панель вместо того, чтобы рисоваться под ней",
        "Workspace pips": "Точки рабочих столов",
        "Writes border settings into your compositor config. Leave off to keep managing them yourself.": "Записывает настройки рамок в конфиг композитора. Оставьте выключенным, чтобы управлять ими самостоятельно.",
        "Another agent is already running": "Уже запущен другой агент",
        "Apply now": "Применить сейчас",
        "Applying\u2026": "Применение\u2026",
        "Bluetooth is off": "Bluetooth выключен",
        "Network & Internet": "Сеть и Интернет",
        "Search": "Поиск",
        "Multitasking": "Многозадачность",
        "Not connected": "Не подключено",
        "Connect": "Подключить",
        "Disconnect": "Отключить",
        "Secured": "Защищённая",
        "Open": "Открыть",
        "Scan": "Поиск",
        "Scanning": "Идёт поиск",
        "Trusted": "Доверенное",
        "Not paired": "Не сопряжено",
        "Forget": "Забыть",
        "Address": "Адрес",
        "Battery": "Батарея",
        "Adapter": "Адаптер",
        "Elsewhere": "В другом месте",
        "Connections": "Подключения",
        "Wi-Fi": "Wi-Fi",
        "Scan for networks": "Искать сети",
        "Scan for devices": "Искать устройства",
        "Network settings": "Настройки сети",
        "Bluetooth settings": "Настройки Bluetooth",
        "Forget this device": "Забыть это устройство",
        "No adapter": "Нет адаптера",
        "No Wi-Fi adapter": "Нет адаптера Wi-Fi",
        "No Bluetooth adapter": "Нет адаптера Bluetooth",
        "Wi-Fi off": "Wi-Fi выключен",
        "Wired connection active": "Проводное подключение активно",
        "Offline": "Не в сети",
        "Connected": "Подключено",
        "Wired": "Проводная",
        "Off": "Выкл",
        "Charge": "Заряд",
        "Charging": "Зарядка",
        "Condition": "Состояние",
        "Draw": "Расход",
        "Fully charged": "Заряжена",
        "No battery on this machine": "На этом компьютере нет батареи",
        "On battery": "От батареи",
        "remaining": "осталось",
        "to full": "до полной",
        "Focused": "Активное",
        "Focused, from": "Активное, от",
        "From palette": "Из палитры",
        "In use": "Используется",
        "Margin above and below": "Отступ сверху и снизу",
        "Margin either side": "Отступ по бокам",
        "Mic off": "Микр. выкл",
        "Mic on": "Микр. вкл",
        "Microphone muted": "Микрофон выключен",
        "Microphone on": "Микрофон включён",
        "Motion by category": "Движение по категориям",
        "Curve, length and entry direction for each surface family": "Кривая, длительность и направление появления для каждой группы поверхностей",
        "Curve": "Кривая",
        "Direction": "Направление",
        "Duration": "Длительность",
        "Auto follows the edge the surface opens from": "«Авто» следует краю, от которого открывается поверхность",
        "after speed": "с учётом скорости",
        "Motion is off": "Движение отключено",
        "auto": "авто",
        "fade": "затухание",
        "scale": "масштаб",
        "up": "вверх",
        "down": "вниз",
        "left": "влево",
        "right": "вправо",
        "glitch": "глитч",
        "Muted": "Без звука",
        "No backlight detected on this machine": "Подсветка на этой машине не обнаружена",
        "No networks found": "Сети не найдены",
        "Output": "Вывод",
        "Output muted": "Звук выключен",
        "Volume +": "Громкость +",
        "Volume -": "Громкость -",
        "Brightness +": "Яркость +",
        "Brightness -": "Яркость -",
        "Unmuted": "Звук включён",
        "Microphone": "Микрофон",
        "Unknown track": "Неизвестный трек",
        "Keyboard layout": "Раскладка клавиатуры",
        "Emoji": "Эмодзи",
        "Recent": "Недавние",
        "Smileys & Emotion": "Смайлы и эмоции",
        "People & Body": "Люди и тело",
        "Animals & Nature": "Животные и природа",
        "Food & Drink": "Еда и напитки",
        "Travel & Places": "Путешествия и места",
        "Activities": "Занятия",
        "Objects": "Предметы",
        "Symbols": "Символы",
        "Flags": "Флаги",
        "Paste": "Вставить",
        "Type to search by name": "Начните печатать для поиска по названию",
        "Brightness changes": "Меняется яркость",
        "Media keys are pressed": "Нажаты медиаклавиши",
        "Sent by the compositor's key bindings over IPC. Each key keeps its own command and adds a call to: qs -c bw77-shell ipc call osd ...": "Приходит из привязок клавиш композитора по IPC. Каждая клавиша сохраняет свою команду и добавляет вызов: qs -c bw77-shell ipc call osd ...",
        "The overlay shown for volume, brightness, media keys and lock keys": "Оверлей для громкости, яркости, медиаклавиш и клавиш-переключателей",
        "Overridden": "Переопределено",
        "Pairing": "Сопряжение",
        "Pin to dock": "Закрепить в доке",
        "Press SCAN to find devices": "Нажмите ПОИСК для поиска устройств",
        "Registered": "Зарегистрирован",
        "SCAN": "ПОИСК",
        "SCANNING": "ПОИСК\u2026",
        "Tap to pair": "Нажмите для сопряжения",
        "The backlight slider": "Ползунок подсветки",
        "Unpin from dock": "Открепить от дока",
        "Use": "Выбрать",
        "Using a custom colour": "Используется свой цвет",
        "Using a palette role": "Используется роль палитры",
        "Volume is passed in this player's own units": "Громкость передаётся в собственных единицах этого проигрывателя",
        "Where the icons sit along the edge": "Где значки расположены вдоль края",
        "Where the icons sit down the edge": "Где значки расположены по краю",
        "Wi-Fi is off": "Wi-Fi выключен",
        "Yellow": "Жёлтый"
        })
    })

    /*
     * Write one motion field.
     *
     * Mutating a nested object inside a `var` property does not emit a change
     * signal - the property still points at the same object - so every binding
     * reading it would keep the old value until something else happened to
     * refresh. Rebuild and reassign.
     */
    function setMotion(category, key, value) {
        const all = Object.assign({}, animations.motion);
        const one = Object.assign({}, all[category] || {});
        one[key] = value;
        all[category] = one;
        animations.motion = all;
    }

    function resetMotion(category) {
        const all = Object.assign({}, animations.motion);
        delete all[category];
        animations.motion = all;
    }

    function t(source) {
        const lang = general ? general.language : "en";
        if (!lang || lang === "en") return source;
        const table = translations[lang];
        if (!table) return source;
        const hit = table[source];
        return hit === undefined ? source : hit;
    }

    /*
     * --- persistence, coalesced
     *
     * Every write serialises the whole settings tree and puts it on disk, and
     * the adapter reports a change per property assignment. A slider drag
     * assigns on every mouse-move event, so dragging one control across its
     * range wrote the entire file dozens of times a second - on the UI thread,
     * inside the same event handler that was supposed to be moving the chip.
     * That is why adjusting anything in the Control Center felt heavier than
     * the rest of the shell, and why it got worse the more settings there were.
     *
     * A short debounce collapses a burst into one write. The window is well
     * under the time it takes to let go of a slider and reach for something
     * else, so a change is on disk before it could plausibly be lost, and any
     * caller wanting the old guarantee can still ask for saveNow().
     */
    Timer {
        id: saveTimer
        interval: 300
        onTriggered: fileView.writeAdapter()
    }

    function save() {
        saveTimer.restart();
    }

    // Bypasses the debounce. For anything that must be durable before the next
    // thing happens - a write the shell is about to be restarted across.
    function saveNow() {
        saveTimer.stop();
        fileView.writeAdapter();
    }

    /*
     * --- restore defaults, one group at a time
     *
     * [F1] in the Control Center resets the category on screen, which means
     * something has to know what "default" was. Rather than maintaining a
     * second copy of every default below - a list that would drift from the
     * real one the first time anybody added a setting - the adapter is read
     * once at startup, while it still holds nothing but its declared values.
     *
     * The timing is what makes this safe: the FileView below cannot have
     * overwritten anything yet, because its first read is gated behind the
     * mkdir Process exiting, and that cannot happen before this component has
     * finished constructing.
     */
    readonly property var groupNames: [
        "general", "polkit", "decoration", "fx", "bar", "clock", "borders",
        "animations", "audio", "quickSettings", "osd", "theme", "dock",
        "desktop", "launcher", "notifications", "wallpaper", "lock", "appTheming"
    ]

    property var defaults: ({})

    Component.onCompleted: {
        const out = {};
        for (let i = 0; i < groupNames.length; i++) {
            const name = groupNames[i];
            const group = adapter[name];
            if (group) out[name] = captureGroup(group);
        }
        defaults = out;
        migrate();
    }

    function captureGroup(group) {
        const out = {};
        for (const key in group) {
            // Property change signals come through the same enumeration as the
            // properties themselves, and both arrive as functions.
            if (typeof group[key] === "function") continue;
            if (key === "objectName") continue;

            const value = group[key];
            if (value !== null && typeof value === "object") {
                // Deep copy, or resetting twice would hand back the same array
                // the user had already edited the first time.
                try {
                    out[key] = JSON.parse(JSON.stringify(value));
                } catch (e) {
                    continue;   // not representable; leave it alone on reset
                }
            } else {
                out[key] = value;
            }
        }
        return out;
    }

    /*
     * --- merging newly shipped entries into a saved list
     *
     * Several settings are arrays of { id, enabled } objects - the quick
     * settings header buttons, its tiles, its sections. They are arrays because
     * the order is the display order and the user is allowed to change it.
     *
     * The consequence is that adding an entry to the defaults below does
     * nothing at all for anyone who already has a settings.json: JsonAdapter
     * loads the saved array verbatim, and the new entry is not in it. That is
     * how the wallpaper button shipped and then failed to appear - the Quick
     * Settings panel filters its buttons against this list, so an id the list
     * has never heard of is not merely un-toggled, it is invisible, and the
     * Control Center had no row to turn it on with either.
     *
     * So a saved list is reconciled against the shipped one on load. Entries
     * the user has are left exactly as they are, including their order and
     * their enabled state; entries only the defaults have are inserted at the
     * position they were declared at, so a new button lands where it was
     * designed to sit rather than being appended to the end.
     *
     * Nothing is ever removed. An id in the file that this build does not know
     * about is most likely from a newer build, and deleting it would make
     * downgrading destructive.
     */
    function mergeIdList(groupName, key) {
        const group = adapter[groupName];
        const shipped = defaults[groupName] ? defaults[groupName][key] : null;
        if (!group || !shipped || shipped.length === undefined) return false;

        const saved = group[key];
        if (!saved || saved.length === undefined) {
            group[key] = JSON.parse(JSON.stringify(shipped));
            return true;
        }

        const have = {};
        for (let i = 0; i < saved.length; i++)
            if (saved[i] && saved[i].id !== undefined) have[saved[i].id] = true;

        const out = saved.slice();
        let added = 0;

        for (let i = 0; i < shipped.length; i++) {
            const entry = shipped[i];
            if (!entry || entry.id === undefined || have[entry.id]) continue;
            // Declared position, clamped - the saved list may be shorter.
            out.splice(Math.min(i, out.length), 0, JSON.parse(JSON.stringify(entry)));
            added++;
        }

        if (added === 0) return false;
        group[key] = out;
        return true;
    }

    /*
     * Runs once, after both the defaults snapshot and the file are in hand.
     *
     * Which of those two arrives first is not fixed - the snapshot is taken
     * when this component completes, the file load is gated behind a Process -
     * so both paths call this and it does nothing until it has both.
     */
    property bool migrated: false

    // Bumped when a stored value changes meaning rather than merely gaining a
    // sibling. migrate() brings older files up to it; a file written fresh is
    // stamped with it and skips the rewrite.
    readonly property int schemaVersion: 1

    function migrate() {
        if (migrated) return;
        if (!loaded || !defaults || Object.keys(defaults).length === 0) return;
        migrated = true;

        let changed = false;

        /*
         * The bar's "floating" became "detached".
         *
         * The name was freed for the new frameless style, so a file written
         * before that says "floating" and means the framed block. Renaming it
         * here keeps the bar someone already had; the version stamp is what
         * stops it renaming a bar they deliberately set to the new floating
         * afterwards.
         */
        if (adapter.schema < 1) {
            if (adapter.bar.style === "floating") {
                adapter.bar.style = "detached";
                changed = true;
            }
            adapter.schema = root.schemaVersion;
            changed = true;
        }

        changed = mergeIdList("quickSettings", "headerButtons") || changed;
        changed = mergeIdList("quickSettings", "tiles") || changed;
        changed = mergeIdList("quickSettings", "sections") || changed;

        if (changed) save();
    }

    /*
     * Restore a set of groups, or named keys within them.
     *
     * Each entry is either "group" or "group:keyA,keyB". The second form exists
     * because the settings groups and the Control Center's categories are not
     * the same carving: `general` holds the interface language, the two font
     * families, the text size and the motion switch, and those show up on three
     * different panes. Resetting Theme should restore the typography without
     * quietly putting the interface back into English.
     *
     * Returns how many groups it actually touched, so a caller can decline to
     * report a reset that did not happen.
     */
    function resetGroups(specs) {
        if (!specs || specs.length === 0) return 0;
        let done = 0;

        for (let i = 0; i < specs.length; i++) {
            const parts = String(specs[i]).split(":");
            const name = parts[0];
            const only = parts.length > 1 ? parts[1].split(",") : null;

            const snapshot = defaults[name];
            const group = adapter[name];
            if (!snapshot || !group) continue;

            const keys = only ? only : Object.keys(snapshot);

            for (let k = 0; k < keys.length; k++) {
                const key = keys[k];
                if (!(key in snapshot)) continue;
                try {
                    const value = snapshot[key];
                    group[key] = (value !== null && typeof value === "object")
                        ? JSON.parse(JSON.stringify(value))
                        : value;
                } catch (e) {
                    console.warn("bw77: could not reset", name + "." + key, e);
                }
            }
            done++;
        }

        if (done > 0) save();
        return done;
    }

    // writeAdapter() will not create missing parent directories, so on a fresh
    // install there is nowhere to save and every setting silently resets on
    // restart. Create the tree first, then load.
    Process {
        id: ensureDirs
        running: true
        command: ["mkdir", "-p",
                  root.configDir,
                  `${root.configDir}/palettes`,
                  `${root.configDir}/state`]
        onExited: fileView.reload()
    }

    FileView {
        id: fileView
        path: root.configPath
        watchChanges: true

        onFileChanged: reload()
        // Debounced - see save() above. A drag reports one adapter update per
        // mouse-move and each one used to rewrite the file.
        onAdapterUpdated: root.save()
        onLoadFailed: {
            // Most commonly the file does not exist yet. Writing the adapter
            // creates it with the defaults declared below, which need no
            // reconciling - they are the defaults.
            adapter.schema = root.schemaVersion;
            writeAdapter();
            root.loaded = true;
            root.migrated = true;
        }
        onLoaded: {
            root.loaded = true;
            root.migrate();
        }

        JsonAdapter {
            id: adapter

            // See schemaVersion. Zero means "written before this existed".
            property int schema: 0

            property JsonObject general: JsonObject {
                // Interface language. Anything without a translation falls
                // back to the English source string, so a partial dictionary
                // degrades to a mixed UI rather than to blank labels.
                property string language: "en"    // en | ru

                property real scale: 1.0            // global UI scale multiplier

                /*
                 * Two faces, not three.
                 *
                 * There were separate display, body and mono families, which
                 * is one more decision than the shell can actually show the
                 * consequences of: display and body sat a few pixels apart on
                 * the same screen in the same weight, and telling them apart in
                 * the picker meant setting one to something absurd to find out
                 * which labels moved. The real split is between text and the
                 * Nerd Font glyphs, because getting that one wrong replaces
                 * every icon in the shell with a box.
                 */
                property string fontUI: "Chakra Petch"
                property string fontIcons: "JetBrainsMono Nerd Font"

                property int fontSizeBase: 13

                /*
                 * Manual vertical trim for text, in pixels, on top of the
                 * automatic optical centring in CyberText.
                 *
                 * The automatic figure centres the cap height, which is right
                 * for the capitals the shell is mostly set in. A face used
                 * largely in mixed case, or one whose declared capitalHeight
                 * does not match its drawn capitals, can still want a pixel
                 * either way - so there is a knob rather than a promise that
                 * one formula suits every font. Zero for most.
                 */
                property int textNudge: 0

                // Multiplies the text size to get the icon size. Above one by
                // default because a Nerd Font glyph never fills its em box the
                // way a letter does; see Theme.fontIcon.
                property real iconScale: 1.3
                property bool reducedMotion: false
            }

            property JsonObject polkit: JsonObject {
                // Only one polkit agent may register per session, so this is
                // off until asked for - turning it on while polkit-gnome or
                // another shell is running would simply fail to register.
                property bool enabled: false
            }

            property JsonObject decoration: JsonObject {
                // Drawn by every framed surface - top bar, quick settings and
                // the dock - so they read as one system rather than three
                // panels that happen to share a palette.
                property string style: "line"        // line | solid | border | none
                property string colorRole: "danger"
                property string colorCustom: ""
                property int thickness: 1

                // How far the gradient fades in from each end, as a fraction of
                // the rule's length. Only meaningful for the line style.
                property real fade: 0.15
            }

            property JsonObject fx: JsonObject {
                property bool scanlines: true
                property real scanlineOpacity: 0.05

                // The slow vertical sweep, and how long one pass takes. It was
                // hardcoded on and hardcoded at 2600ms, so the only way to stop
                // it was to turn scanlines off altogether.
                property bool scanlineDrift: true
                property int scanlineDriftDuration: 2600
                property bool glitchOnOpen: true
                property bool cornerTicks: true      // the little L-brackets on frames
                property bool telemetryText: true    // fake serials like TRN_TLCAS_800095
            }

            property JsonObject bar: JsonObject {
                property string position: "top"      // top | bottom
                property int height: 34

                /*
                 * attached - edge to edge, flush against the screen edge.
                 * detached - a block with its own margins, width and frame.
                 * floating - that block with no frame: just the widgets.
                 *
                 * "floating" used to mean what "detached" means now, so
                 * migrate() renames it in an existing config - otherwise
                 * everyone who had a floating bar would lose its frame on
                 * upgrade.
                 */
                property string style: "attached"    // attached | detached | floating
                property int marginH: 12
                property int marginV: 8
                property int floatingWidth: 0        // 0 = as wide as the screen allows
                property int notch: 10               // chamfer size when floating

                // The edge rule now lives in the shared `decoration` group, so
                // the bar, quick settings and dock stay in step with one another.

                // Widget outlines: on hover only, or always at reduced opacity.
                property string widgetBorders: "hover"   // hover | always | never
                property real widgetBorderOpacity: 0.35
                property bool exclusive: true

                // Gap between widgets, and the breathing room inside each one.
                property int widgetSpacing: 8
                property int widgetPadding: 8
                property int sectionPadding: 12

                /*
                 * Text size and weight for the whole bar.
                 *
                 * These used to be per-widget: every widget's option tab
                 * carried its own "Text size" slider, all defaulting to 0
                 * meaning "use the theme". That produced a row of controls
                 * whose only sane setting was to leave them all identical, and
                 * whose failure mode was a bar where the clock was 13px, the
                 * battery 15px and nobody could remember which tab had been
                 * touched. A bar is one strip of text; it gets one size.
                 *
                 * Zero still means "use the theme size", so an untouched
                 * config looks exactly as it did before.
                 */
                property int fontSize: 0

                /*
                 * Weight is a slider rather than a bold switch because the
                 * interesting range on a condensed display face is not
                 * regular-versus-bold, it is the three or four steps between
                 * them. Qt maps these onto whatever the family actually ships
                 * and picks the nearest, so a family with only two weights
                 * still behaves - it just has fewer distinct stops.
                 *
                 * 500 is Medium, which is what CyberText already used.
                 */
                property int fontWeight: 500

                // Tray appearance. Icons ship at wildly different native sizes,
                // so a fixed pixel size is the only way to keep the row even.
                property int trayIconSize: 16
                property bool trayColorize: false
                property bool customTrayMenu: true
                property string trayColorRole: "accent"   // any Theme role name
                property string trayColorCustom: ""       // "#rrggbb" wins over the role
                property var monitors: []            // [] = all screens
                // Widget placement. Reorder / move between sections freely.
                property var left: [
                    { "id": "controlCenter" },
                    { "id": "workspaces" },
                    { "id": "activeWindow", "maxWidth": 320 }
                ]
                property var center: [
                    { "id": "clock", "format": "HH:mm:ss" }
                ]
                property var right: [
                    { "id": "sysmon", "showCpu": true, "showRam": true, "showTemp": true },
                    { "id": "keyboardLayout" },
                    { "id": "tray" },
                    { "id": "volume" },
                    { "id": "network" },
                    { "id": "battery" },
                    { "id": "session" }
                ]
            }

            property JsonObject clock: JsonObject {
                property string timeFormat: "HH:mm:ss"
                property string dateFormat: "ddd dd.MM.yyyy"
                property bool showDate: true
            }

            property JsonObject borders: JsonObject {
                // Window borders are drawn by the compositor, not the shell, so
                // these are written out through the app-theming templates.
                property bool manage: false
                property bool gradient: true
                property int gradientAngle: 45
                property int width: 2
                property int radius: 0

                // Each colour is a palette role, or a literal that overrides it.
                property string activeFromRole: "accent"
                property string activeFromCustom: ""
                property string activeToRole: "danger"
                property string activeToCustom: ""
                property string inactiveRole: "border"
                property string inactiveCustom: ""
                property string urgentRole: "warn"
                property string urgentCustom: ""
            }

            property JsonObject animations: JsonObject {
                /*
                 * Per-category motion overrides, keyed by the categories in
                 * Theme.motionCategories. Only what the user actually changed
                 * is stored; anything absent falls back to Theme.motionDefaults,
                 * so the file stays small and new categories pick up sensible
                 * values without a migration.
                 */
                property var motion: ({})

                // Multiplies every duration in the theme. 0 disables motion
                // entirely, which is the same as the reduce-motion switch.
                property real speed: 1.0
                property bool surfaceOpen: true      // scale-in on popups and panels
                property bool textDecode: true       // the character scramble
                property bool workspaceMorph: true   // pip widening on focus
                property bool barHover: true         // widget hover fills
                property bool notificationEntry: true
                property bool wallpaperTransition: true
            }

            property JsonObject audio: JsonObject {
                // Substring match against an audio stream's application name or
                // node name. Anything matching never appears in the mixer.
                property var streamBlacklist: [
                    "cava", "peak detect", "gsr-", "gpu-screen-recorder", "obs-"
                ]
            }

            property JsonObject quickSettings: JsonObject {
                property string side: "right"        // right | left
                property int width: 380

                // Section order is the display order; each entry can be turned
                // off and given its own colour without touching the others.
                property var sections: [
                    { "id": "header",        "enabled": true,  "color": "danger"  },
                    { "id": "toggles",       "enabled": true,  "color": "accent"  },
                    { "id": "volume",        "enabled": true,  "color": "accent"  },
                    { "id": "brightness",    "enabled": true,  "color": "warn"    },
                    { "id": "media",         "enabled": false, "color": "warn"    },
                    { "id": "notifications", "enabled": true,  "color": "text"    },
                    { "id": "calendar",      "enabled": true,  "color": "accent"  }
                ]

                // The calendar is pinned to the bottom of the panel rather than
                // flowing with the rest, so it stays put as history grows.
                property bool pinCalendar: true

                /*
                 * Individual elements inside sections.
                 *
                 * Separate from `sections` because turning off a whole section
                 * is a coarser decision than hiding one tile within it.
                 */
                property var headerButtons: [
                    { "id": "controlCenter", "enabled": true },
                    { "id": "wallpaper",     "enabled": true },
                    { "id": "theme",         "enabled": true },
                    { "id": "session",       "enabled": true }
                ]

                property var tiles: [
                    { "id": "network",       "enabled": true },
                    { "id": "bluetooth",     "enabled": true },
                    { "id": "power",         "enabled": true },
                    { "id": "dnd",           "enabled": true },
                    { "id": "sound",         "enabled": true },
                    { "id": "mic",           "enabled": true },
                    { "id": "reduceMotion",  "enabled": true }
                ]

                property bool showMicSlider: true

                property int notificationsShown: 5
                property bool groupNotifications: true
                property bool showSeconds: false
            }

            property JsonObject osd: JsonObject {
                property bool enabled: true
                property string position: "bottom-center"  // *-left | *-center | *-right
                property string style: "arc"               // arc | bar
                property int timeout: 1600
                property bool showPercent: true
                property bool onVolume: true
                property bool onMute: true
                property bool onMicMute: true

                // Both of these arrive over IPC from the compositor's key
                // bindings, not from watching state - see OsdLayer.
                property bool onBrightness: true
                property bool onMedia: true

                // Lock keys are one toggle, the layout is another: they come
                // from different places (keyboard LEDs versus the compositor)
                // and one of them costs a poll while it is on.
                property bool onLocks: false
                property bool onKeyboardLayout: false

                property int size: 150
            }

            property JsonObject theme: JsonObject {
                // Palette id, not the project name. Matches a file in
                // Config/Palettes or ~/.config/bw77-shell/palettes.
                property string name: "nightcity"
                property bool followWallpaper: false // derive palette via ColorQuantizer
                property var overrides: ({})         // role -> "#rrggbb", wins over the palette file
            }

            property JsonObject dock: JsonObject {
                // Show the entry points an application declares in its
                // .desktop file (Brave's incognito window, LibreOffice's
                // document types) in the right-click menu.
                property bool showAppActions: true

                property bool enabled: false
                property string position: "bottom"   // bottom | left | right | top

                // Mirrors the bar. "attached" runs the full length of its edge
                // and sits flush against it; "floating" is a detached block
                // sized to its icons, with its own margins.
                property string style: "floating"    // floating | attached
                property int marginH: 12             // along the edge, floating only
                property int marginV: 8              // away from the edge, floating only

                // Where the icons sit along the edge. Stored side-neutral
                // because which end "start" means depends on the position:
                // left/right for a horizontal dock, top/bottom for a vertical
                // one. The Control Center relabels it to match.
                property string alignment: "center"  // start | center | end

                property int iconSize: 40
                property int spacing: 8
                property int padding: 8
                property int notch: 12

                // none keeps the dock always visible and reserving space.
                property string hideMode: "none"     // none | autohide | intelligent
                property int hideDelay: 400
                property int revealSize: 4           // hot edge thickness, px

                // Hovering an icon lifts it and its neighbours, Dash-to-Dock style.
                property bool magnify: true
                property real magnifyScale: 1.45
                property int magnifyRange: 2

                property bool showRunning: true      // running apps that are not pinned
                property bool showIndicators: true   // dot under running apps
                property bool showLabels: true       // tooltip on hover

                // Per-icon outline, mirroring the top bar widget setting.
                property string itemBorders: "hover"   // hover | always | never
                property real itemBorderOpacity: 0.30

                // Indicator colour for the application that currently has focus.
                property string focusedColorRole: "gold"
                property string focusedColorCustom: ""

                // Force every dock icon to a single colour from the palette.
                property bool colorizeIcons: false
                property string iconColorRole: "accent"
                property string iconColorCustom: ""
                property real colorizeStrength: 1.0
                property bool colorizeFocusedApp: false

                property bool showLauncher: true
                property string launcherPosition: "start"   // start | end
                property string clickAction: "cycle" // cycle | activate | minimise

                property var pinned: [
                    "firefox", "org.kde.dolphin", "kitty", "code"
                ]
                property var monitors: []            // [] = all screens
            }

            property JsonObject desktop: JsonObject {
                property bool enabled: true
                property bool editMode: false
                // Snapping is a separate switch rather than "set the grid to
                // 1". Turning it off and back on should return the spacing you
                // had, and a single number cannot remember it.
                /*
                 * How solid a desktop widget is over the wallpaper.
                 *
                 * The one surface in the shell that is deliberately not opaque.
                 * Everything else sits over the desktop briefly and has to be
                 * read; these sit there permanently and have to be lived with.
                 */
                property real widgetOpacity: 0.72

                property bool snapToGrid: true
                property real gridSnap: 8
                property var widgets: [
                    { "type": "sysmon", "screen": "", "x": 40, "y": 80, "w": 300, "h": 220 },
                    { "type": "visualizer", "screen": "", "x": 40, "y": 320, "w": 300, "h": 120 },
                    { "type": "media", "screen": "", "x": 40, "y": 460, "w": 300, "h": 140 }
                ]
            }

            property JsonObject launcher: JsonObject {
                property int width: 720
                property int maxResults: 40
                property string position: "center"   // center | top
                property int height: 520
                property bool showCategories: true
                property string categoryLayout: "vertical"  // vertical | horizontal
                property int categoryWidth: 150
                property bool showIcons: true
                property var categoryOrder: [
                    "Web Browser", "Messaging", "Audio & Video", "Graphics",
                    "Development", "Office", "Education", "Games", "Network", "System", "Other"
                ]
            }

            property JsonObject emoji: JsonObject {
                // Most recent first, each as [emoji, name, keywords] - the same
                // shape as an entry in Assets/emoji.json, so the Recent tab
                // needs no lookup. One grid page's worth is kept.
                property var recent: []

                // Every method copies with wl-copy first. Then:
                //   auto  - type into terminals, Ctrl+V everywhere else
                //   type  - type it with wtype (fails in browsers)
                //   paste - send Ctrl+V (not paste in terminals)
                //   copy  - clipboard only
                property string pasteMethod: "auto"
            }

            property JsonObject notifications: JsonObject {
                // top-left | top-center | top-right | bottom-left | bottom-center | bottom-right
                property string position: "top-right"
                // Keeps toasts clear of the bar instead of tucking under it.
                property bool avoidBar: true
                property int edgeMargin: 12
                property int width: 380
                property int timeout: 6000
                property int maxVisible: 5
                property bool sound: true
                property real soundVolume: 0.5
                property string soundCommand: "pw-play"
                property string soundFileNormal: ""
                property string soundFileCritical: ""
                property string animation: "glitch"  // glitch | slide | fade
                property bool doNotDisturb: false
            }

            property JsonObject wallpaper: JsonObject {
                // image draws a file; colour draws a flat or gradient fill
                // taken from the palette, so the desktop follows the theme.
                property string mode: "image"        // image | color
                property string colorStyle: "gradient"  // solid | gradient
                property string colorRole: "bgBase"
                property string colorCustom: ""
                property string colorRole2: "bgOverlay"
                property string colorCustom2: ""
                property int gradientAngle: 160

                property string folder: `${Quickshell.env("HOME")}/Pictures/Wallpapers`
                property string current: ""
                property bool perMonitor: false
                property var monitorMap: ({})
                property bool randomize: false
                property int randomIntervalSec: 1800
                property string transition: "glitch" // glitch | fade | none

                // Second background surface for niri's overview backdrop. See
                // Modules/Wallpaper/WallpaperLayer.qml for why it is separate.
                property bool niriBackdrop: true

                /*
                 * Build the backdrop surface only while the overview is open.
                 *
                 * It is a full-screen layer surface per monitor, and with blur
                 * on it carries a full-screen offscreen buffer as well - none
                 * of which is ever on screen outside the overview. Off keeps it
                 * resident for the whole session, which is what it used to do.
                 */
                property bool backdropOnDemand: true
                property real backdropDim: 0.55

                // niri has no blur of its own, so the backdrop surface blurs
                // itself. 0 leaves it sharp.
                property real backdropBlur: 0.7
                property string setCommand: ""       // empty = use built-in wallpaper layer
            }

            property JsonObject lock: JsonObject {
                property bool blurWallpaper: true
                property string clockFormat: "HH:mm"
            }

            property JsonObject appTheming: JsonObject {
                property bool enabled: false
                property var targets: ({
                    "gtk": false, "libadwaita": false, "flatpak": false, "qt": false, "kitty": false, "ghostty": false,
                    "foot": false, "alacritty": false, "wezterm": false,
                    "discord": false, "vscode": false, "btop": false, "cava": false,
                    "niri": false, "hyprland": false, "fuzzel": false, "starship": false,
                    "micro": false
                })

                // Push colours to terminals that are already open, rather than
                // only to the next one launched.
                property bool liveReload: true

                // Saturation multiplier for exported terminal colours. 1 keeps
                // the palette's own character; higher pushes it louder.
                property real vibrance: 1.15
            }
        }
    }
}

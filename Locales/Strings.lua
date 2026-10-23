local _, addon = ...
local strings = {
    enUS = { ["SEARCH_OBJECTIVE_MATCH"] = "Quest objective: %s", ["SEARCH_NPC_MATCH"] = "NPC: %s", ["SEARCH_PLACE_MATCH"] = "Place: %s", ["OBJECTIVE_ITEM_SOURCES"] = "Where to find quest items", ["OBJECTIVE_ITEM_SOURCES_NOTICE"] = "Reported item sources; availability is not confirmed.", ["LANGUAGE_AUTO_SHORT"] = "Auto", ["QUEST_LEVEL"] = "Quest level: %.0f", ["TURNIN_REFERENCE_PORTRAIT"] = "Turn-in: %s", ["DIALOGUE_PROGRESS_TEXT"] = "Current quest dialogue", ["DIALOGUE_TURNIN_TEXT"] = "Current turn-in dialogue", ["GAME_WAYPOINT"] = "Game waypoint", ["GAME_WAYPOINT_NOTICE"] = "The waypoint may lead along a route, to an entrance, or to a turn-in location.", ["GAME_WAYPOINT_FOLLOW"] = "Follow game waypoint", ["QUEST_LOG_PAYMENT"] = "Quest log payment: %s", ["PREPARATION_EMPTY"] = "No preparation steps are shown. Switch to %s to view the listed quests.", ["QUEST_PAYMENT"] = "Source-listed payment: %s", ["MONEY_COPPER"] = "%.0f copper", ["QUEST_PAYMENT_NOTICE"] = "This listed cost does not confirm quest availability.", ["SEARCH_QUEST_MATCH"] = "Quest: %s", ["STORY_SOURCE_QUESTS"] = "Quests in the story list: %d", ["OBJECTIVE_OBJECTS"] = "Other listed objectives", ["OBJECTIVE_OBJECTS_NOTICE"] = "These tasks are quest objectives, not confirmed pickup conditions or current progress.", ["OPEN_QUEST_LOG"] = "Open in quest log", ["QUEST_TEXT"] = "Quest text", ["ITEM_DROP_LOCATIONS"] = "Known item drop locations — availability unconfirmed", ["ITEM_ACQUISITION"] = "Getting the starter item", ["ITEM_ACQUISITION_UNKNOWN"] = "Acquisition source has not been verified.", ["PROVIDED_ITEMS"] = "Quest-provided items", ["PROVIDED_ITEMS_NOTICE"] = "Provided items may be used or consumed during the quest. Current possession is shown separately.", ["OBJECTIVE_KILLS"] = "Listed kill objectives", ["OBJECTIVE_KILLS_NOTICE"] = "Listed targets are quest objectives, not confirmed pickup conditions or current progress.", ["GIVER_REFERENCE_PORTRAIT"] = "Quest giver: %s", ["QUEST_FACTIONS"] = "Factions: %s", ["PREPARATION_FOR"] = "Preparation for", ["PREPARATION_FOR_NOTICE"] = "Targets in the current preparation plan; other routes may be possible.", ["LANGUAGE_AUTO"] = "Automatic (game language)", ["GUIDE_DISTANCE"] = "%.0f yd", ["BRANCH_INSPECT"] = "View quest", ["OVERVIEW_PICK"] = "Select a listed quest to see its details and preparation steps.", ["OVERVIEW_REVIEWED"] = "Quest list reviewed; individual requirements may still be unverified.", ["FACTION_Alliance"] = "Alliance", ["FACTION_Horde"] = "Horde", ["FACTION_Neutral"] = "Neutral", ["OBJECTIVE_ITEM_UNKNOWN"] = "%s — quantity not verified", ["MINIMAP_OPEN"] = "Left-click: open or close Dungeon Pro.", ["MINIMAP_DRAG"] = "Drag to move around the minimap.", ["OBJECTIVE_ITEMS"] = "Listed item objectives", ["OBJECTIVE_ITEM"] = "%s ×%.0f", ["OBJECTIVE_ITEMS_NOTICE"] = "Listed items are quest objectives, not confirmed pickup conditions or current progress.",  ["QUEST_MIN_LEVEL"] = "Minimum level: %.0f", ["QUEST_CLASSES"] = "Classes: %s", ["QUEST_RACES"] = "Races: %s", ["RACE_ID"] = "Race #%.0f",  ["QUEST_LOG_CAPACITY"] = "Quest log: %.0f/%.0f", ["ITEM_CARRIED"] = "Carried: %.0f", ["DUNGEON_WING_lower"] = "%s — Lower wing", ["DUNGEON_WING_upper"] = "%s — Upper wing", ["REWARD_PREVIEW"] = "Quest reward preview", ["UNKNOWN_REQUIREMENTS"] = "Not in quest log — requirements unverified", ["CONTAINER_SOURCE"] = "Known item container — availability unconfirmed", ["REPORTED_POSITIONS"] = "%s — reported positions (%d)", ["REPORTED_NOTICE"] = "These points may reflect movement or quest phases. They do not confirm the current NPC or object location.", ["REPORTED_VISIT"] = "Visit this reported position", ["COMPLETED_BEFORE"] = "Completed before", ["DETAIL_BACK"] = "Back", ["REQUIREMENT_GROUPS"] = "Known prerequisite groups", ["REQUIREMENT_NOTICE"] = "Every listed group is required; one quest per group is enough. Additional requirements may be unknown.", ["REQUIREMENT_GROUP"] = "Requirement %d", ["REQUIREMENT_ACTIVE"] = "Accept or complete one quest.", ["REQUIREMENT_COMPLETE"] = "Complete one quest.", ["CATALOG_LEVELS"] = "Levels %d–%d", ["CATALOG_QUESTS"] = "Listed quests: %d", ["OBJECTIVE_DIALOGUE"] = "Objective in the open quest dialogue", ["OBJECTIVE_PROGRESS"] = "Objectives reported by the game", ["REWARD_DIALOGUE"] = "Rewards in the open quest dialogue", ["REWARD_HIDDEN"] = "The client is not displaying rewards for this quest.", ["REWARD_XP"] = "Experience: %d",
        POSSIBLE_TURNINS = "Possible turn-in points — availability unconfirmed",
        STORY_GROUP = "Story group %d",
        STORY_GROUP_NOTICE = "The source shows these quests together. This does not confirm prerequisites or which quests your character can accept.",
        START_ALTERNATIVES = "Possible starting points — availability unconfirmed",
        ITEM_STARTER = "Quest-starting item: %s", ITEM_DROP_SOURCE = "Drops from %s in %s.",
        OFFERED_NOW = "Offered in the current NPC dialogue.",
        ITEM_CLASSES = "Item classes: %s", ITEM_MIN_LEVEL = "Item requires level %d.",
        ITEM_REQUIREMENTS_NOTICE = "Item requirements only. Quest availability is checked separately.",
        QUEST_PORTRAIT = "Quest portrait",
        TITLE = "Dungeon Pro", SUBTITLE = "Prepare before you enter", ["SEARCH"] = "Dungeon, quest, NPC",
        RANGE = "My level", ALL = "All levels", QUESTS = "Dungeon quests", CHAIN = "Quest chain",
        NEXT = "Next step", STORY = "Story order (requirements still being checked)", MAP = "Show on map", GUIDE = "Guide me", CLEAR = "Clear guide",
        COMPLETED = "Completed", READY = "Ready to turn in", ACTIVE = "In quest log",
        AVAILABLE = "Available", LOCKED = "Preparation needed", UNAVAILABLE = "Not for this character",
        UNKNOWN = "Not enough information", PARTIAL = "Quest coverage is still being checked",
        EMPTY = "Quest data has not been added for this dungeon yet.", PICK = "Select a dungeon, then a quest.",
        NO_TEXT = "Original quest text is unavailable. Open the quest offer to save it.",
        pickup = "Pick up", inside = "Pick up inside the dungeon", complete = "Finish this quest",
        turnin = "Turn in", level = "Reach level", SOURCE = "Wowhead link",
        START = "Starts at", ENDING = "Turn in at", UNKNOWN_PLACE = "Location is not yet known",
        SUMMARY = "Taken: %d   Completed: %d   Need preparation: %d   Unknown: %d",
        PREPARED = "Known quests are prepared", NOT_PREPARED = "Preparation remaining",
        PREP_outside = "Pick up before entering", PREP_inside = "Pick up inside the dungeon", PREP_item = "Pick up item",
        PREP_level = "Level requirements", PREP_progress = "Finish or turn in",
        PREP_uncertain = "Requirements still unknown",
        MY_CHARACTER = "My character", ALL_CHARACTERS = "All characters", PREP_unavailable = "Not for this character",
        NO_CHARACTER_QUESTS = "No known quests for this character. Switch to %s to inspect the others.",
        VISIT_GIVER = "Visit quest giver", GIVER_MAP = "Quest giver on map",
        LOCATION_ONLY = "Location only; quest availability is not confirmed.",
        BRANCH_GROUP = "Requirement %d: choose one", BRANCH_AUTO = "Automatic", BRANCH_SELECTED = "%s (selected)",
        REWARD_ITEMS = "Item rewards", REWARD_CHOICES = "Choose one item", REWARD_ITEM = "%s ×%d",
        REWARD_NO_ITEMS = "No item rewards.", REWARD_UNAVAILABLE = "Reward data is unavailable for this quest.",
        REWARD_MONEY = "Money", REWARD_MONEY_UNKNOWN = "Money reward could not be displayed.",
        ["SEARCH_HELP"] = "Search dungeons, listed quests, recorded NPCs and places, or enter a quest ID. Letter case is ignored; accents and spelling still matter.",
        NO_DUNGEONS = "No dungeons match the current search and filters.",
        REPEATABLE = "Repeatable quest", MATERIAL_QUESTS = "Quests for required materials", MATERIAL_ITEM = "Item #%d",
        MATERIAL_NOTICE = "These quests provide completion materials, not confirmed requirements for accepting this quest. Completing one does not confirm you still hold its item.",
        REASON_requirements = "Required quest steps are still unfinished.",
        REASON_requirementsUnknown = "Quest requirements have not been fully verified.",
        REASON_character = "Quest history or character restrictions could not be checked.",
        REASON_level = "Requires level %d.", REASON_level_current = "Requires level %d; current level: %d.",
        REASON_levelUnknown = "Your level could not be checked.",
        REASON_missing = "Quest information is missing from the catalogue.",
        REASON_cycle = "Quest dependencies contain a cycle; availability cannot be determined.",
        REASON_faction = "Your faction does not meet this quest's requirements.",
        REASON_class = "Your class does not meet this quest's requirements.",
        REASON_race = "Your race does not meet this quest's requirements.",
        DEVELOPMENT = "Development build — dungeon coverage is incomplete",
        NO_POSITION = "Position unavailable or destination is on another continent",
        UNSUPPORTED = "This build supports WoW Forever only.",
        DETAIL_MORE = "More details", DETAIL_LESS = "Hide details",
        DETAIL_CHAIN = "Known quest chain",
        DUNGEON_ENTRANCE = "Dungeon entrance", STEP_MAP = "Current step on map", STEP_GUIDE = "Guide to current step",
        DUNGEON_ENTRANCE_UNKNOWN = "The entrance location has not been verified yet.",
        DUNGEON_ENTRANCE_RECORDED = "Entrance location from a recorded source.",
        QUEST_GIVER = "Quest giver",
        CHAIN_PREVIEW_NOTICE = "Part of the quest chain is shown; expand to see every step.",
        GIVER_LOCATION_UNKNOWN = "Quest giver location is not yet known.",
        SOURCE_POSITION_UNKNOWN = "Exact location is not yet known.",
        QUEST_START_UNKNOWN = "How to start this quest is not yet known.",
        SOURCE_SUMMON_ITEM = "Use %s to create %s.",
        SOURCE_SUMMON_HINT = "Use the listed item to create this object.",
        GIVER_COORDINATES_UNKNOWN = "Precise coordinates are unavailable; only the known area can be shown.",
        DUNGEON_ENTRANCE_SHARED = "Shared entrance; follow the route to your wing inside.",
        ENTRANCE_SHARED_ACTION = "Shared entrance", ENTRANCE_APPROACH_ACTION = "Dungeon approach",
        DUNGEON_ENTRANCE_APPROACH = "Approach to the dungeon; the portal is farther inside.",
        ONLY_EN_RU = "Language", COPY = "Select the link and press Ctrl+C.",
    },
    ruRU = { ["SEARCH_OBJECTIVE_MATCH"] = "Цель задания: %s", ["SEARCH_NPC_MATCH"] = "НИП: %s", ["SEARCH_PLACE_MATCH"] = "Место: %s", ["OBJECTIVE_ITEM_SOURCES"] = "Где найти предметы для задания", ["OBJECTIVE_ITEM_SOURCES_NOTICE"] = "Указанные места получения; доступность предметов не подтверждена.", ["LANGUAGE_AUTO_SHORT"] = "Авто", ["QUEST_LEVEL"] = "Уровень задания: %.0f", ["TURNIN_REFERENCE_PORTRAIT"] = "Сдача задания: %s", ["DIALOGUE_PROGRESS_TEXT"] = "Текущий диалог задания", ["DIALOGUE_TURNIN_TEXT"] = "Текущий диалог сдачи задания", ["GAME_WAYPOINT"] = "Метка игры", ["GAME_WAYPOINT_NOTICE"] = "Метка может указывать путь, вход или место сдачи задания.", ["GAME_WAYPOINT_FOLLOW"] = "Следовать метке игры", ["QUEST_LOG_PAYMENT"] = "Плата по журналу заданий: %s", ["PREPARATION_EMPTY"] = "В этом режиме нет шагов подготовки. Переключитесь на «%s», чтобы посмотреть список заданий.", ["QUEST_PAYMENT"] = "Указанная плата: %s", ["MONEY_COPPER"] = "%.0f мед.", ["QUEST_PAYMENT_NOTICE"] = "Указанная плата не подтверждает доступность задания.", ["SEARCH_QUEST_MATCH"] = "Задание: %s", ["STORY_SOURCE_QUESTS"] = "Заданий в сюжетном списке: %d", ["OBJECTIVE_OBJECTS"] = "Дополнительные цели задания", ["OBJECTIVE_OBJECTS_NOTICE"] = "Указанные цели не подтверждают условия получения задания или текущий прогресс.", ["OPEN_QUEST_LOG"] = "Открыть в журнале заданий", ["QUEST_TEXT"] = "Текст задания", ["ITEM_DROP_LOCATIONS"] = "Известные места добычи предмета — доступность не подтверждена", ["ITEM_ACQUISITION"] = "Где найти предмет для начала задания", ["ITEM_ACQUISITION_UNKNOWN"] = "Источник получения предмета пока не подтверждён.", ["PROVIDED_ITEMS"] = "Предметы, выдаваемые для задания", ["PROVIDED_ITEMS_NOTICE"] = "Выданные предметы могут использоваться или расходоваться во время задания. Текущее количество при персонаже показано отдельно.", ["OBJECTIVE_KILLS"] = "Указанные цели для убийства", ["OBJECTIVE_KILLS_NOTICE"] = "Указанные цели относятся к задачам задания, а не к подтверждённым условиям получения или текущему прогрессу.", ["GIVER_REFERENCE_PORTRAIT"] = "Квестодатель: %s", ["QUEST_FACTIONS"] = "Фракции: %s", ["PREPARATION_FOR"] = "Подготовка к заданиям", ["PREPARATION_FOR_NOTICE"] = "Цели текущего плана подготовки; могут существовать другие пути.", ["LANGUAGE_AUTO"] = "Автоматически (язык игры)", ["GUIDE_DISTANCE"] = "%.0f ярд.", ["BRANCH_INSPECT"] = "Посмотреть задание", ["OVERVIEW_PICK"] = "Выберите задание из списка, чтобы посмотреть его условия и подготовку.", ["OVERVIEW_REVIEWED"] = "Список заданий проверен; отдельные условия могут оставаться неподтверждёнными.", ["FACTION_Alliance"] = "Альянс", ["FACTION_Horde"] = "Орда", ["FACTION_Neutral"] = "Нейтральная", ["OBJECTIVE_ITEM_UNKNOWN"] = "%s — количество не подтверждено", ["MINIMAP_OPEN"] = "Левый клик: открыть или закрыть Dungeon Pro.", ["MINIMAP_DRAG"] = "Перетащите значок вокруг мини-карты.", ["OBJECTIVE_ITEMS"] = "Указанные предметные цели", ["OBJECTIVE_ITEM"] = "%s ×%.0f", ["OBJECTIVE_ITEMS_NOTICE"] = "Перечисленные предметы — цели задания, а не подтверждённые условия его принятия или текущий прогресс.",  ["QUEST_MIN_LEVEL"] = "Минимальный уровень: %.0f", ["QUEST_CLASSES"] = "Классы: %s", ["QUEST_RACES"] = "Расы: %s", ["RACE_ID"] = "Раса №%.0f",  ["QUEST_LOG_CAPACITY"] = "Журнал заданий: %.0f/%.0f", ["ITEM_CARRIED"] = "При себе: %.0f", ["DUNGEON_WING_lower"] = "%s — Нижнее крыло", ["DUNGEON_WING_upper"] = "%s — Верхнее крыло", ["REWARD_PREVIEW"] = "Предварительный просмотр наград", ["UNKNOWN_REQUIREMENTS"] = "Нет в журнале — условия не проверены", ["CONTAINER_SOURCE"] = "Известный контейнер предмета — доступность не подтверждена", ["REPORTED_POSITIONS"] = "%s — отмеченные позиции (%d)", ["REPORTED_NOTICE"] = "Эти точки могут отражать перемещения или разные фазы задания. Текущее положение NPC или объекта не подтверждено.", ["REPORTED_VISIT"] = "Посетить эту отмеченную точку", ["COMPLETED_BEFORE"] = "Выполнялось ранее", ["DETAIL_BACK"] = "Назад", ["REQUIREMENT_GROUPS"] = "Известные группы предпосылок", ["REQUIREMENT_NOTICE"] = "Нужна каждая указанная группа; достаточно одного задания в каждой. Дополнительные условия могут быть неизвестны.", ["REQUIREMENT_GROUP"] = "Условие %d", ["REQUIREMENT_ACTIVE"] = "Принять или выполнить одно задание.", ["REQUIREMENT_COMPLETE"] = "Выполнить одно задание.", ["CATALOG_LEVELS"] = "Уровни %d–%d", ["CATALOG_QUESTS"] = "Заданий в каталоге: %d", ["OBJECTIVE_DIALOGUE"] = "Цель в открытом диалоге задания", ["OBJECTIVE_PROGRESS"] = "Цели по данным игры", ["REWARD_DIALOGUE"] = "Награды в открытом диалоге задания", ["REWARD_HIDDEN"] = "Клиент не показывает награды этого задания.", ["REWARD_XP"] = "Опыт: %d",
        POSSIBLE_TURNINS = "Возможные места сдачи — доступность не подтверждена",
        STORY_GROUP = "Группа сюжета %d",
        STORY_GROUP_NOTICE = "Источник объединяет эти задания. Это не подтверждает требования или доступность заданий вашему персонажу.",
        START_ALTERNATIVES = "Возможные места начала — доступность не подтверждена",
        ITEM_STARTER = "Предмет для начала задания: %s", ITEM_DROP_SOURCE = "Выпадает с %s в %s.",
        OFFERED_NOW = "Предлагается в текущем диалоге с NPC.",
        ITEM_CLASSES = "Классы предмета: %s", ITEM_MIN_LEVEL = "Предмет требует уровень %d.",
        ITEM_REQUIREMENTS_NOTICE = "Требования предмета. Условия получения задания проверяются отдельно.",
        QUEST_PORTRAIT = "Портрет из журнала",
        TITLE = "Dungeon Pro", SUBTITLE = "Подготовься перед походом", ["SEARCH"] = "Подземелье, квест, НИП",
        RANGE = "Мой уровень", ALL = "Все уровни", QUESTS = "Задания подземелья", CHAIN = "Цепочка заданий",
        NEXT = "Следующий шаг", STORY = "Порядок сюжета (условия ещё проверяются)", MAP = "Показать на карте", GUIDE = "Указать направление", CLEAR = "Убрать указатель",
        COMPLETED = "Выполнено", READY = "Можно сдавать", ACTIVE = "В журнале заданий",
        AVAILABLE = "Можно взять", LOCKED = "Нужна подготовка", UNAVAILABLE = "Не для этого персонажа",
        UNKNOWN = "Недостаточно данных", PARTIAL = "Полнота списка заданий ещё проверяется",
        EMPTY = "Задания этого подземелья пока не добавлены в базу.", PICK = "Выбери подземелье, затем задание.",
        NO_TEXT = "Исходный текст задания недоступен. Открой окно получения задания, чтобы сохранить его.",
        pickup = "Взять задание", inside = "Взять внутри подземелья", complete = "Выполнить задание",
        turnin = "Сдать задание", level = "Достичь уровня", SOURCE = "Ссылка на Wowhead",
        START = "Где взять", ENDING = "Где сдать", UNKNOWN_PLACE = "Местоположение пока неизвестно",
        SUMMARY = "Взято: %d   Выполнено: %d   Нужна подготовка: %d   Нет данных: %d",
        PREPARED = "Известные задания подготовлены", NOT_PREPARED = "Подготовка не завершена",
        PREP_outside = "Взять до входа", PREP_inside = "Взять внутри подземелья", PREP_item = "Взять предмет",
        PREP_level = "Требования к уровню", PREP_progress = "Выполнить или сдать",
        PREP_uncertain = "Условия пока неизвестны",
        MY_CHARACTER = "Мой персонаж", ALL_CHARACTERS = "Все персонажи", PREP_unavailable = "Не для этого персонажа",
        NO_CHARACTER_QUESTS = "Известных заданий для этого персонажа нет. Выбери «%s», чтобы посмотреть остальные.",
        VISIT_GIVER = "К квестодателю", GIVER_MAP = "Квестодатель на карте",
        LOCATION_ONLY = "Только местоположение; доступность задания не подтверждена.",
        BRANCH_GROUP = "Условие %d: выбери один вариант", BRANCH_AUTO = "Автоматически", BRANCH_SELECTED = "%s (выбрано)",
        REWARD_ITEMS = "Предметы в награду", REWARD_CHOICES = "Выбери один предмет", REWARD_ITEM = "%s ×%d",
        REWARD_NO_ITEMS = "Предметов в награду нет.", REWARD_UNAVAILABLE = "Данные о наградах этого задания недоступны.",
        REWARD_MONEY = "Деньги", REWARD_MONEY_UNKNOWN = "Не удалось отобразить денежную награду.",
        ["SEARCH_HELP"] = "Поиск подземелий, заданий, известных НИП и мест без учёта регистра. Можно ввести ID задания. Учитываются диакритика и написание.",
        NO_DUNGEONS = "Нет подземелий, соответствующих поиску и выбранным фильтрам.",
        REPEATABLE = "Повторяемое задание", MATERIAL_QUESTS = "Задания на нужные материалы", MATERIAL_ITEM = "Предмет №%d",
        MATERIAL_NOTICE = "Это источники материалов для сдачи, а не подтверждённые условия получения задания. Выполненное задание не подтверждает, что предмет ещё у тебя.",
        REASON_requirements = "Нужные шаги цепочки ещё не пройдены.",
        REASON_requirementsUnknown = "Условия получения задания ещё не полностью проверены.",
        REASON_character = "Не удалось проверить историю заданий или ограничения персонажа.",
        REASON_level = "Нужен уровень %d.", REASON_level_current = "Нужен уровень %d; текущий: %d.",
        REASON_levelUnknown = "Не удалось определить твой уровень.",
        REASON_missing = "Сведения об этом задании отсутствуют в базе.",
        REASON_cycle = "В условиях заданий найден цикл; доступность определить нельзя.",
        REASON_faction = "Задание недоступно твоей фракции.",
        REASON_class = "Задание недоступно твоему классу.",
        REASON_race = "Задание недоступно твоей расе.",
        DEVELOPMENT = "Версия в разработке — база подземелий ещё неполная",
        NO_POSITION = "Позиция недоступна или цель на другом континенте",
        UNSUPPORTED = "Эта сборка предназначена для WoW Forever.",
        DETAIL_MORE = "Подробнее", DETAIL_LESS = "Скрыть подробности",
        DETAIL_CHAIN = "Известная цепочка",
        DUNGEON_ENTRANCE = "Вход в подземелье", STEP_MAP = "Текущий шаг на карте", STEP_GUIDE = "К текущему шагу",
        DUNGEON_ENTRANCE_UNKNOWN = "Точка входа пока не подтверждена.",
        DUNGEON_ENTRANCE_RECORDED = "Точка входа по данным источника.",
        QUEST_GIVER = "Квестодатель",
        CHAIN_PREVIEW_NOTICE = "Показана часть цепочки; разверните её, чтобы увидеть все задания.",
        GIVER_LOCATION_UNKNOWN = "Местоположение квестодателя пока неизвестно.",
        SOURCE_POSITION_UNKNOWN = "Точное местоположение пока неизвестно.",
        QUEST_START_UNKNOWN = "Способ начала этого задания пока неизвестен.",
        SOURCE_SUMMON_ITEM = "Используйте %s — появится %s.",
        SOURCE_SUMMON_HINT = "Используйте указанный предмет, чтобы создать этот объект.",
        GIVER_COORDINATES_UNKNOWN = "Точные координаты недоступны; можно показать только известную область.",
        DUNGEON_ENTRANCE_SHARED = "Общий вход; путь к нужному крылу продолжается внутри.",
        ENTRANCE_SHARED_ACTION = "Общий вход", ENTRANCE_APPROACH_ACTION = "Подход к подземелью",
        DUNGEON_ENTRANCE_APPROACH = "Подход к подземелью; портал находится дальше внутри.",
        ONLY_EN_RU = "Язык", COPY = "Выдели ссылку и нажми Ctrl+C.",
    },
}
addon.locales = strings
strings.enUS.STORY_SHORT = "Story"
strings.ruRU.STORY_SHORT = "Сюжет"
strings.enUS.REQUIRED_STEP_SHORT = "Prerequisite"
strings.ruRU.REQUIRED_STEP_SHORT = "Условие"
strings.enUS.DETAIL_RECORDED_OBJECTIVES = "Listed objectives"
strings.ruRU.DETAIL_RECORDED_OBJECTIVES = "Справочные цели"
strings.enUS.CHAIN_TRUNCATED_NOTICE = "Only part of this chain is shown."
strings.ruRU.CHAIN_TRUNCATED_NOTICE = "Показана только часть этой цепочки."
strings.enUS.VISIT_TURNIN = "Visit turn-in point"
strings.ruRU.VISIT_TURNIN = "К месту сдачи задания"
strings.enUS.ANCESTOR_ACTION = "Next known step"
strings.ruRU.ANCESTOR_ACTION = "Следующий известный шаг"
strings.enUS.CATALOG_HIDE = "Hide dungeon list"
strings.ruRU.CATALOG_HIDE = "Скрыть список подземелий"
strings.enUS.CATALOG_SHOW = "Show dungeon list"
strings.ruRU.CATALOG_SHOW = "Показать список подземелий"
strings.enUS.TAB_QUEST, strings.enUS.TAB_SOURCES, strings.enUS.TAB_STORY = "Quest", "Sources", "Story"
strings.ruRU.TAB_QUEST, strings.ruRU.TAB_SOURCES, strings.ruRU.TAB_STORY = "Задание", "Источники", "История"
strings.enUS.DETAIL_STORY_UNAVAILABLE = "Quest story text is not available yet. Open the quest offer to save it."
strings.ruRU.DETAIL_STORY_UNAVAILABLE = "Текст задания пока недоступен. Откройте окно получения задания, чтобы сохранить его."
strings.enUS.ITEM_SOURCE_SUMMARY = "Listed sources: %d. See %s."
strings.ruRU.ITEM_SOURCE_SUMMARY = "Мест получения: %d. См. «%s»."
strings.enUS.REPORT_ISSUE, strings.enUS.SUPPORT_AUTHOR, strings.enUS.CLOSE = "Report an issue", "Support the project", "Close"
strings.ruRU.REPORT_ISSUE, strings.ruRU.SUPPORT_AUTHOR, strings.ruRU.CLOSE = "Сообщить о проблеме", "Поддержать проект", "Закрыть"
strings.enUS.LEVEL_FILTER, strings.enUS.CHARACTER_FILTER, strings.enUS.FILTER_SWITCH = "Level filter", "Character filter", "Click: %s"
strings.ruRU.LEVEL_FILTER, strings.ruRU.CHARACTER_FILTER, strings.ruRU.FILTER_SWITCH = "Фильтр уровня", "Фильтр персонажа", "Нажатие: %s"
strings.enUS.DUNGEON_QUEST_SHORT, strings.ruRU.DUNGEON_QUEST_SHORT = "Dungeon", "В данж"
strings.enUS.DUNGEON_MAP_OPEN = "Dungeon map"
strings.enUS.DUNGEON_MAP_BACK = "Back to details"
strings.enUS.DUNGEON_MAP_RETRY = "Retry"
strings.enUS.DUNGEON_MAP_UNAVAILABLE = "A map is not available for this dungeon."
strings.enUS.DUNGEON_MAP_SHARED = "This map covers multiple dungeon wings."
strings.enUS.DUNGEON_MAP_FLOOR = "Floor %d"
strings.enUS.DUNGEON_MAP_PREVIOUS = "Previous floor"
strings.enUS.DUNGEON_MAP_NEXT = "Next floor"
strings.ruRU.DUNGEON_MAP_OPEN = "Карта подземелья"
strings.ruRU.DUNGEON_MAP_BACK = "Назад к описанию"
strings.ruRU.DUNGEON_MAP_RETRY = "Повторить"
strings.ruRU.DUNGEON_MAP_UNAVAILABLE = "Карта этого подземелья недоступна."
strings.ruRU.DUNGEON_MAP_SHARED = "Общая карта нескольких крыльев подземелья."
strings.ruRU.DUNGEON_MAP_FLOOR = "Этаж %d"
strings.ruRU.DUNGEON_MAP_PREVIOUS = "Предыдущий этаж"
strings.ruRU.DUNGEON_MAP_NEXT = "Следующий этаж"

strings.enUS.SEARCH_RELATED_STEP = "Related step: %s"
strings.ruRU.SEARCH_RELATED_STEP = "Связанный шаг: %s"

strings.enUS.OVERVIEW_PREPARATION = "Listed quest progress"
strings.enUS.OVERVIEW_STATUS_ACTIVE = "Ready to turn in: %d · In progress: %d"
strings.enUS.OVERVIEW_STATUS_RECORDED = "Completed: %d · Uncertain: %d"
strings.enUS.OVERVIEW_STATUS_COUNT = "%s: %d"
strings.enUS.OVERVIEW_KNOWN_STEPS = "From your quest log"
strings.enUS.OVERVIEW_NEXT_STEPS = "Next steps"
strings.enUS.OVERVIEW_NO_KNOWN_STEPS = "No steps are listed. Select a quest for details."
strings.enUS.OVERVIEW_UNCERTAIN = "Some quest conditions or coverage remain unverified."
strings.enUS.OVERVIEW_SUPPORTING_QUEST = "Supporting quest"
strings.enUS.OVERVIEW_MORE_STEPS = "%d more steps are not shown here."
strings.ruRU.OVERVIEW_PREPARATION = "Состояние заданий подземелья"
strings.ruRU.OVERVIEW_STATUS_ACTIVE = "К сдаче: %d · Выполняются: %d"
strings.ruRU.OVERVIEW_STATUS_RECORDED = "Выполнены: %d · Неизвестно: %d"
strings.ruRU.OVERVIEW_STATUS_COUNT = "%s: %d"
strings.ruRU.OVERVIEW_KNOWN_STEPS = "Шаги из журнала заданий"
strings.ruRU.OVERVIEW_NEXT_STEPS = "Следующие шаги"
strings.ruRU.OVERVIEW_NO_KNOWN_STEPS = "Шагов нет. Выберите задание, чтобы посмотреть подробности."
strings.ruRU.OVERVIEW_UNCERTAIN = "Часть условий или сведений о заданиях пока не проверена."
strings.ruRU.OVERVIEW_SUPPORTING_QUEST = "Вспомогательное задание"
strings.ruRU.OVERVIEW_MORE_STEPS = "Ещё шагов не показано: %d."

function addon.L(key, ...)
    -- Fail-closed: non-string keys return as-is instead of throwing at the
    -- table index below. All live callers pass string literals; this guards
    -- the latent L(nil) path before the pcall-format guard.
    if type(key) ~= "string" then return key end
    -- Reader hardening: namespace reads never throw. A corrupted SavedVariables
    -- table (DungeonProDB=5), a hostile addon.db/Clean overwrite, a throwing
    -- language metatable, or a poisoned locale table falls back to "auto"/enUS
    -- instead of aborting the UI update. Mirrors nameLocaleScope() in
    -- Core/Client.lua: Clean only through a type-checked capture, rawget for
    -- every metatable-sensitive read.
    local clean = type(rawget(addon, "Clean")) == "function" and rawget(addon, "Clean")
    if not clean then
        -- Namespace adapters unavailable (standalone locale testbed) or
        -- overwritten: plain type checks keep literal lookups working instead
        -- of collapsing every locale to enUS. Never throws; never indexes.
        clean = function(value, kind) if type(value) ~= kind then return nil end return value end
    end
    local read = type(rawget(addon, "Read")) == "function" and rawget(addon, "Read")
    local db = clean and clean(rawget(addon, "db"), "table")
    local locale = (db and clean(rawget(db, "locale"), "string")) or "auto"
    local language = clean and clean(rawget(addon, "Language"), "table")
    local previewGetter = language and clean(rawget(language, "GetSelection"), "function")
    local preview = previewGetter and read and read(previewGetter, "string", language)
    if preview then locale = preview end
    if locale == "auto" then
        if type(GetLocale) == "function" then
            local ok, detected = pcall(GetLocale)
            if ok and type(detected) == "string" then locale = detected else locale = "enUS" end
        else
            locale = "enUS"
        end
    end
    if locale == "enGB" then locale = "enUS" end
    if locale == "esMX" then locale = "esES" end
    -- Poisoned locale tables (strings.deDE=5) fall back to enUS, never throw.
    local catalog = (type(strings) == "table" and type(locale) == "string") and rawget(strings, locale) or nil
    if type(catalog) ~= "table" then catalog = nil end
    local fallback = type(strings) == "table" and rawget(strings, "enUS") or nil
    if type(fallback) ~= "table" then fallback = nil end
    local text = (catalog and rawget(catalog, key)) or (fallback and rawget(fallback, key)) or key
    if type(text) ~= "string" then text = key end
    -- Malformed catalog-fed format args fail closed to the raw text, never an aborted UI update.
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok and type(formatted) == "string" then return formatted end
        return text
    end
    return text
end

strings.enUS.BACK = strings.enUS.DETAIL_BACK
strings.ruRU.BACK = strings.ruRU.DETAIL_BACK

local moreLabels = {
    enUS = {"Show more (%d)","Show fewer"},
    ruRU = {"Показать ещё (%d)","Показать меньше"},
}
for locale,values in pairs(moreLabels) do addon.locales[locale].OVERVIEW_SHOW_MORE=values[1];addon.locales[locale].OVERVIEW_SHOW_FEWER=values[2] end

-- Reviewed full Scarlet wing labels; Italian records retain the English fallback.
strings.enUS.DUNGEON_SCARLET_graveyard = "Scarlet Monastery - Graveyard"
strings.enUS.DUNGEON_SCARLET_library = "Scarlet Monastery - Library"
strings.enUS.DUNGEON_SCARLET_armory = "Scarlet Monastery - Armory"
strings.enUS.DUNGEON_SCARLET_cathedral = "Scarlet Monastery - Cathedral"
-- Interface copy: explicit Russian; other locales retain English fallback.
strings.enUS.SM_SHARED_LEVEL_RANGE = "Monastery: %d–%d"
strings.enUS.SM_WING_QUESTS_UNKNOWN = "Wing quests: unverified"
strings.enUS.SM_CHOOSE_WING = "Choose a monastery wing"
strings.enUS.SM_PARTIAL_WING = "Quest coverage for this wing is incomplete."
strings.ruRU.DUNGEON_SCARLET_graveyard = "Монастырь Алого ордена: кладбище"
strings.ruRU.DUNGEON_SCARLET_library = "Монастырь Алого ордена: библиотека"
strings.ruRU.DUNGEON_SCARLET_armory = "Монастырь Алого ордена: оружейная"
strings.ruRU.DUNGEON_SCARLET_cathedral = "Монастырь Алого ордена: собор"
-- Interface copy: explicit Russian; other locales retain English fallback.
strings.ruRU.SM_SHARED_LEVEL_RANGE = "Монастырь: %d–%d"
strings.ruRU.SM_WING_QUESTS_UNKNOWN = "Задания крыла: не проверены"
strings.ruRU.SM_CHOOSE_WING = "Выбери крыло монастыря"
strings.ruRU.SM_PARTIAL_WING = "Список заданий этого крыла ещё не проверен полностью."

strings.enUS.SM_CLASSIC_BADGE = "Classic"
strings.enUS.SM_CLASSIC_QUEST = "Wing assignment: Classic"
strings.enUS.SM_CLASSIC_MULTI_WING = "Classic · objectives in several wings"
strings.enUS.SM_SHARED_QUESTS = "Monastery quest index"
strings.ruRU.SM_CLASSIC_BADGE = "Classic"
strings.ruRU.SM_CLASSIC_QUEST = "Распределение по крыльям: Classic"
strings.ruRU.SM_CLASSIC_MULTI_WING = "Classic · цели в нескольких крыльях"
strings.ruRU.SM_SHARED_QUESTS = "Список заданий монастыря"

strings.enUS.PROFESSION = "Profession: %s"
strings.enUS.PROFESSION_BLACKSMITHING = "Blacksmithing"
strings.ruRU.PROFESSION = "Профессия: %s"
strings.ruRU.PROFESSION_BLACKSMITHING = "Кузнечное дело"

local _, addon = ...
local strings = {
    enUS = {
        TITLE = "DungeonPrep", SUBTITLE = "Prepare before you enter", SEARCH = "Search dungeons",
        RANGE = "My level", ALL = "All levels", QUESTS = "Dungeon quests", CHAIN = "Quest chain",
        NEXT = "Next step", STORY = "Story order (requirements still being checked)", MAP = "Show on map", GUIDE = "Guide me", CLEAR = "Clear guide",
        COMPLETED = "Completed", READY = "Ready to turn in", ACTIVE = "In quest log",
        AVAILABLE = "Available", LOCKED = "Preparation needed", UNAVAILABLE = "Not for this character",
        UNKNOWN = "Not enough information", PARTIAL = "Quest coverage is still being checked",
        EMPTY = "Quest data has not been added for this dungeon yet.", PICK = "Select a dungeon, then a quest.",
        NO_TEXT = "Quest text is saved when you open the quest at its giver.",
        pickup = "Pick up", inside = "Pick up inside the dungeon", complete = "Finish this quest",
        turnin = "Turn in", level = "Reach level", SOURCE = "Wowhead link",
        START = "Starts at", ENDING = "Turn in at", UNKNOWN_PLACE = "Location is not yet known",
        SUMMARY = "Taken: %d   Completed: %d   Need preparation: %d   Unknown: %d",
        PREPARED = "Known quests are prepared", NOT_PREPARED = "Preparation remaining",
        DEVELOPMENT = "Development build — dungeon coverage is incomplete",
        NO_POSITION = "Position unavailable or destination is on another continent",
        UNSUPPORTED = "This build supports WoW Forever only.",
        ONLY_EN_RU = "Language", COPY = "Select the link and press Ctrl+C.",
    },
    ruRU = {
        TITLE = "DungeonPrep", SUBTITLE = "Подготовься перед походом", SEARCH = "Поиск подземелий",
        RANGE = "Мой уровень", ALL = "Все уровни", QUESTS = "Задания подземелья", CHAIN = "Цепочка заданий",
        NEXT = "Следующий шаг", STORY = "Порядок сюжета (условия ещё проверяются)", MAP = "Показать на карте", GUIDE = "Указать направление", CLEAR = "Убрать указатель",
        COMPLETED = "Выполнено", READY = "Можно сдавать", ACTIVE = "В журнале заданий",
        AVAILABLE = "Можно взять", LOCKED = "Нужна подготовка", UNAVAILABLE = "Не для этого персонажа",
        UNKNOWN = "Недостаточно данных", PARTIAL = "Полнота списка заданий ещё проверяется",
        EMPTY = "Задания этого подземелья пока не добавлены в базу.", PICK = "Выбери подземелье, затем задание.",
        NO_TEXT = "Текст сохраняется при открытии задания у квестодателя.",
        pickup = "Взять задание", inside = "Взять внутри подземелья", complete = "Выполнить задание",
        turnin = "Сдать задание", level = "Достичь уровня", SOURCE = "Ссылка на Wowhead",
        START = "Где взять", ENDING = "Где сдать", UNKNOWN_PLACE = "Местоположение пока неизвестно",
        SUMMARY = "Взято: %d   Выполнено: %d   Нужна подготовка: %d   Нет данных: %d",
        PREPARED = "Известные задания подготовлены", NOT_PREPARED = "Подготовка не завершена",
        DEVELOPMENT = "Версия в разработке — база подземелий ещё неполная",
        NO_POSITION = "Позиция недоступна или цель на другом континенте",
        UNSUPPORTED = "Эта сборка предназначена для WoW Forever.",
        ONLY_EN_RU = "Язык", COPY = "Выдели ссылку и нажми Ctrl+C.",
    },
}
addon.locales = strings
function addon.L(key, ...)
    local locale = addon.db and addon.db.locale or "auto"
    if locale == "auto" then locale = GetLocale() end
    if locale == "enGB" then locale = "enUS" end
    if locale == "esMX" then locale = "esES" end
    local text = (strings[locale] or strings.enUS)[key] or strings.enUS[key] or key
    if select("#", ...) > 0 then return string.format(text, ...) end
    return text
end

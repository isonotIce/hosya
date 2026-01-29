script_name('HOSYA by d4nek')
script_author('HOSYA')
script_version('1.2.4')
script_description('Скрипт проверки активности, под редакцией d4nek')

local ev = require 'lib.samp.events'
local vkeys = require'vkeys'
local imgui = require 'mimgui'
local new = imgui.new
local encoding = require("encoding")
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local ffi = require("ffi")

-- ================== СИСТЕМА ОБНОВЛЕНИЯ ==================
local UPDATE_URL = "https://raw.githubusercontent.com/isonotIce/hosya/tree/main/checkactivity.lua"
local VERSION_CHECK_URL = "https://raw.githubusercontent.com/isonotIce/hosya/tree/main/version.txt"
local SCRIPT_NAME = "checkactivity.lua"
local UPDATE_FOLDER = "moonloader\\updates\\"
local BACKUP_FOLDER = "moonloader\\backups\\"

-- Переменные для обновления
local update_available = false
local current_version = "1.2.4"
local latest_version = "1.2.3"
local update_changelog = ""
local update_progress = 0
local update_status = ""
local is_checking_update = false
local is_downloading = false
local renderUpdateWindow = new.bool(false)

-- Функция для создания резервной копии
local function create_backup()
    if not doesDirectoryExist(BACKUP_FOLDER) then
        os.execute('mkdir "' .. BACKUP_FOLDER .. '" 2>nul')
    end
    
    local backup_file = BACKUP_FOLDER .. SCRIPT_NAME .. "_backup_" .. os.date("%Y%m%d_%H%M%S") .. ".lua"
    
    -- Читаем текущий файл
    local file = io.open(SCRIPT_NAME, "rb")
    if file then
        local content = file:read("*a")
        file:close()
        
        -- Сохраняем резервную копию
        local backup = io.open(backup_file, "wb")
        if backup then
            backup:write(content)
            backup:close()
            return true, backup_file
        end
    end
    return false, ""
end

-- Функция для проверки обновлений
local function check_for_updates()
    if is_checking_update then return end
    
    is_checking_update = true
    update_status = "Проверка обновлений..."
    
    lua_thread.create(function()
        -- Пробуем скачать файл версии
        local temp_version_file = UPDATE_FOLDER .. "version_temp.txt"
        downloadUrlToFile(VERSION_CHECK_URL, temp_version_file, function(id, status)
            if status == 0 then -- SUCCESS
                -- Читаем файл версии
                local file = io.open(temp_version_file, "r")
                if file then
                    local content = file:read("*a")
                    file:close()
                    os.remove(temp_version_file)
                    
                    -- Парсим версию и changelog
                    local version_line = content:match("version:%s*(%d+%.%d+%.%d+)")
                    local changelog = content:match("changelog:%s*(.+)") or ""
                    
                    if version_line then
                        latest_version = version_line
                        update_changelog = changelog
                        
                        -- Сравниваем версии
                        local function version_to_table(ver)
                            local t = {}
                            for num in ver:gmatch("%d+") do
                                table.insert(t, tonumber(num))
                            end
                            return t
                        end
                        
                        local current_t = version_to_table(current_version)
                        local latest_t = version_to_table(latest_version)
                        
                        update_available = false
                        for i = 1, math.max(#current_t, #latest_t) do
                            local cur = current_t[i] or 0
                            local lat = latest_t[i] or 0
                            if lat > cur then
                                update_available = true
                                break
                            elseif lat < cur then
                                break
                            end
                        end
                        
                        if update_available then
                            update_status = "Доступно обновление до v" .. latest_version
                            show_chat_notification("info", "Доступно обновление", 
                                "Нажмите F11 и перейдите в меню обновлений")
                        else
                            update_status = "У вас последняя версия"
                        end
                    else
                        update_status = "Ошибка чтения версии"
                    end
                else
                    update_status = "Ошибка чтения файла"
                end
            else
                update_status = "Ошибка соединения"
            end
            is_checking_update = false
        end)
    end)
end

-- Функция для скачивания обновления
local function download_update()
    if is_downloading then return end
    
    is_downloading = true
    update_progress = 0
    update_status = "Начинаем загрузку..."
    
    -- Создаем папку для обновлений
    if not doesDirectoryExist(UPDATE_FOLDER) then
        os.execute('mkdir "' .. UPDATE_FOLDER .. '" 2>nul')
    end
    
    local temp_file = UPDATE_FOLDER .. SCRIPT_NAME .. "_update.lua"
    
    lua_thread.create(function()
        -- Создаем резервную копию
        local backup_success, backup_path = create_backup()
        if backup_success then
            update_status = "Резервная копия создана"
        end
        
        -- Скачиваем обновление
        downloadUrlToFile(UPDATE_URL, temp_file, function(id, status, p1, p2)
            if status == 0 then -- DOWNLOADING
                update_progress = p1 / p2 * 100
                update_status = string.format("Загрузка: %.1f%%", update_progress)
            elseif status == 1 then -- SUCCESS
                update_progress = 100
                update_status = "Загрузка завершена"
                
                -- Читаем скачанный файл
                local update_file = io.open(temp_file, "rb")
                if update_file then
                    local new_content = update_file:read("*a")
                    update_file:close()
                    
                    -- Записываем поверх текущего файла
                    local current_file = io.open(SCRIPT_NAME, "wb")
                    if current_file then
                        current_file:write(new_content)
                        current_file:close()
                        
                        -- Удаляем временный файл
                        os.remove(temp_file)
                        
                        update_status = "Обновление установлено!"
                        show_chat_notification("success", "Обновление установлено", 
                            "Перезапустите скрипт (F5) для применения изменений")
                        
                        -- Показываем окно с завершением
                        lua_thread.create(function()
                            wait(3000)
                            is_downloading = false
                            renderUpdateWindow[0] = false
                        end)
                    else
                        update_status = "Ошибка записи файла"
                        is_downloading = false
                    end
                else
                    update_status = "Ошибка чтения обновления"
                    is_downloading = false
                end
            elseif status == 2 then -- ERROR
                update_status = "Ошибка загрузки"
                is_downloading = false
            end
        end)
    end)
end

-- Функция для автоматической проверки обновлений при запуске
local function auto_check_updates()
    lua_thread.create(function()
        wait(5000) -- Ждем 5 секунд после запуска
        check_for_updates()
        
        -- Если есть обновление, показываем уведомление
        wait(3000) -- Ждем завершения проверки
        if update_available then
            show_chat_notification("info", "Доступно обновление", 
                string.format("Версия v%s -> v%s. Нажмите F11 для установки", current_version, latest_version))
        end
    end)
end

local function ru(text)
    if text == nil then return "" end
    local status, result = pcall(function() 
        return u8:encode(tostring(text))
    end)
    return status and result or tostring(text)
end

local function unru(text)
    if text == nil then return "" end
    local status, result = pcall(function() 
        return u8:decode(tostring(text))
    end)
    return status and result or tostring(text)
end

local function safe_chat(msg)
    if msg and msg ~= "" then
        local status, err = pcall(function()
            local cp1251_msg = u8:decode(msg)
            sampAddChatMessage(cp1251_msg, -1)
        end)
        if not status then
            pcall(function()
                sampAddChatMessage(msg, -1)
            end)
        end
    end
end

local function chat(msg)
    safe_chat(msg)
end

local function chat_colored(hex_color, text)
    if text and text ~= "" then
        local status, result = pcall(function()
            return u8:decode(tostring(text))
        end)
        
        local final_text = status and result or tostring(text)
        local colored_msg = string.format("{%06X}%s", hex_color, final_text)
        sampAddChatMessage(colored_msg, -1)
    end
end

if not string.lpad then
    string.lpad = function(str, len, char)
        if char == nil then char = ' ' end
        str = tostring(str)
        if #str >= len then return str end
        return str .. string.rep(char, len - #str)
    end
end

local function get_msk_time()
    return os.date("%H:%M"), os.date("%w")
end

local function is_check_time_allowed()
    local current_time, current_day_w = get_msk_time()
    local current_day = tonumber(current_day_w)
    if current_day == 0 then current_day = 7 end 
    
    if not config.check_days[current_day] then
        return false, "Проверки не разрешены в этот день"
    end
    
    if current_time < config.check_time_start or current_time > config.check_time_end then
        return false, string.format("Время проверок: %s - %s (MSK)", config.check_time_start, config.check_time_end)
    end
    
    return true, ""
end

local function get_current_time_display()
    local msk_time, _ = get_msk_time()
    return "Текущее время вашего ПК: " .. msk_time
end

-- ================== КОНФИГУРАЦИЯ ==================
local config = {
    theme = "dark_blue",
    auto_save_reports = true,
    show_notifications = true,
    notification_duration = 5,
    check_days = {true, true, true, true, true, false, false},
    check_time_start = "14:00",
    check_time_end = "19:00",
    check_organization = "не установлена",
    enable_check_reminders = true,
    last_check_date = "",
    last_check_org = "",
    max_checks_per_day = 999,
    reminder_interval_minutes = 120,
    auto_check_updates = true -- Новая настройка
}

local config_file = "hosya_config.json"

-- ================== ПЕРЕМЕННЫЕ ==================
local check_members = false
local check_my_lvl_adm = false
local my_lvl_adm = 0
local spisok_org_members = {}

local renderWindow = new.bool(false)
local renderMembersWindow = new.bool(false)
local renderSettingsWindow = new.bool(false)
local renderGovFormWindow = new.bool(false)
local sizeX, sizeY = getScreenResolution()

local my_lvl_adm = 0
local admin_level_text = "Не определен"

local page = 2
local today_checks = 0
local last_check_timestamp = 0
local check_history = {}

local corrent_id_to_rec = 1
local org_id = {
    "LSPD", "RCSD", "FBI", "SFPD", "LSMC", "GOV", 
    "MSP", "SFMC", "GCL", "RCLS", "grove", "vagos", 
    "ballas", "aztec", "rifa", "Russian Mafia", "Yakuza", 
    "LCN", "Warlock", "LSa", "", "LVMC", "LVPD", 
    "RCLV", "NW", "RCSF", "Army SF", "Hitmen", 
    "Insurance Company", "TRB", "Jefferson MC", "Fire Department"
}
local selected_org = 1
local selected_org_name = ru("Выберите организацию")

local check_status_members = false
local status_members = {
    "На обработке", 
    "Работает", 
    "АФК без ЕСК", 
    "АФК", 
    "Занимается личными делами"
}
local keys_check_status_members = {49, 50, 51, 52} 

local last_orgname = ""
local last_time_check_members = ""
local last_time_stop_check_members = ""
local report_history = {}

local loading_members = false
local loading_progress = ""
local loading_dots = ""
local loading_last_update = 0

local org_norms = {
    ["Больница LS"] = 6,
    ["Больница LV"] = 6,
    ["Центр лицензирования"] = 5,
    ["TV студия"] = 5,
    ["Пожарный департамент"] = 10,
    ["Полиция ЛС"] = 10,
    ["Областная полиция"] = 10,
    ["Полиция ЛВ"] = 10,
    ["Полиция СФ"] = 10,
    ["FBI"] = 8,
    ["Армия ЛС"] = 8,
    ["Армия СФ"] = 8,
    ["Правительство LS"] = 7,
    ["Тюрьма строгого режима LV"] = 8,
    ["Больница SF"] = 8,
    ["grove"] = 8,
    ["vagos"] = 8,
    ["ballas"] = 8,
    ["aztec"] = 8,
    ["rifa"] = 8,
    ["Russian Mafia"] = 8,
    ["Yakuza"] = 8,
    ["LCN"] = 8,
    ["Warlock"] = 8,
    ["RCLV"] = 8,
    ["NW"] = 8,
    ["RCSF"] = 8,
    ["Hitmen"] = 8,
    ["Страховая компания"] = 8,
    ["TRB"] = 8,
    ["Больница Jefferson"] = 8
}

local org_9th_point = {
    ["Больница LS"] = "В холле/палатах находится как минимум 1 сотрудник (не афк без еска)",
    ["Больница LV"] = "В холле/палатах находится как минимум 1 сотрудник (не афк без еска)",
    ["Центр лицензирования"] = "В холле находится как минимум 1 сотрудник (не афк без еска)",
    ["TV студия"] = "Как минимум 1 сотрудник редактирует объявления/проводит эфир",
    ["Пожарный департамент"] = "На пожары катается минимум 2 сотрудника",
    ["Полиция ЛС"] = "Состав патрулирует, проводят задержания, трафик стопы и тп",
    ["Областная полиция"] = "Состав патрулирует, проводят задержания, трафик стопы и тп",
    ["Полиция ЛВ"] = "Состав патрулирует, проводят задержания, трафик стопы и тп",
    ["Полиция СФ"] = "Состав патрулирует, проводят задержания, трафик стопы и тп",
    ["FBI"] = "Состав патрулирует, проводят задержания, трафик стопы и тп",
    ["Правительство LS"] = "В холле находится как минимум 1 сотрудник (не афк без еска)",
    ["Армия ЛС"] = "На территории ВЧ минимум 2 сотрудник (не афк без еска)",
    ["Армия СФ"] = "На территории ВЧ минимум 2 сотрудника (не афк без еска)"
}

local gov_form = {
    training_building = new.bool(false),
    interviews_24h = new.bool(false),
    members_count = new.char[10]("0"),
    working_in_form = new.char[10]("0"),
    afk_without_esc = new.char[10]("0"),
    afk_with_warnings = new.char[10]("0"),
    lobby_employee = new.bool(false),
    leader_online = new.bool(false),
    work_with_staff = new.char[32](""),
    work_with_absentees = new.char[32](""),
    min_active = new.bool(false),
    members_norm = new.bool(false)
}

local animation_values = {
    main_window_alpha = 0.0,
    settings_window_alpha = 0.0,
    check_window_alpha = 0.0,
    gov_form_alpha = 0.0,
    update_window_alpha = 0.0,
    notification_fade = 1.0
}

local day_names = {
    "ПН",
    "ВТ",
    "СР",
    "ЧТ",
    "ПТ",
    "СБ",
    "ВС"
}

local auto_save_reports_bool = new.bool(true)
local show_notifications_bool = new.bool(true)
local enable_check_reminders_bool = new.bool(true)
local check_days_bools = {}
for i = 1, 7 do check_days_bools[i] = new.bool(true) end
local check_time_start_input = new.char[6]()
local check_time_end_input = new.char[6]()
local check_org_input = new.char[256]()
local min_interval_input = new.int(2)
local max_checks_input = new.int(999)
local auto_check_updates_bool = new.bool(true) -- Новая переменная

-- ================== ТЕМЫ ==================
local themes = {
    dark_blue = {
        name = "Синий",
        chat_colors = {
            header = 0x00BFFF,
            box_bg = 0x1A2B3C,
            border = 0x2A4B6C,
            text = 0xFFFFFF,
            accent = 0x00BFFF,
            success = 0x32CD32,
            error = 0xFF4444,
            warning = 0xFFA500,
            info = 0x87CEEB
        },
        ui = {
            text = imgui.ImVec4(1.00, 1.00, 1.00, 0.95),
            
            window_bg = imgui.ImVec4(0.08, 0.12, 0.20, 0.92),
            child_bg = imgui.ImVec4(0.10, 0.14, 0.22, 0.88),
            
            border = imgui.ImVec4(0.20, 0.30, 0.45, 0.50),
            
            frame_bg = imgui.ImVec4(0.15, 0.20, 0.30, 0.75),
            frame_hover = imgui.ImVec4(0.20, 0.30, 0.45, 0.80),
            frame_active = imgui.ImVec4(0.25, 0.40, 0.60, 0.90),
            
            button = imgui.ImVec4(0.20, 0.40, 0.70, 0.85),
            button_hover = imgui.ImVec4(0.25, 0.50, 0.85, 0.95),
            button_active = imgui.ImVec4(0.30, 0.60, 1.00, 1.00),
            
            header = imgui.ImVec4(0.25, 0.35, 0.50, 0.80),
            header_hover = imgui.ImVec4(0.30, 0.45, 0.65, 0.85),
            
            separator = imgui.ImVec4(0.30, 0.50, 0.80, 0.60),
            
            accent = imgui.ImVec4(0.00, 0.60, 1.00, 1.00),
            success = imgui.ImVec4(0.00, 0.80, 0.30, 1.00),
            error = imgui.ImVec4(0.90, 0.20, 0.20, 1.00),
            warning = imgui.ImVec4(1.00, 0.70, 0.00, 1.00)
        }
    },
    
    dark_purple = {
        name = "Фиолетовый",
        chat_colors = {
            header = 0x9932CC,
            box_bg = 0x2D1B3C,
            border = 0x4A2B6C,
            text = 0xFFFFFF,
            accent = 0x9932CC,
            success = 0x32CD32,
            error = 0xFF4444,
            warning = 0xFFA500,
            info = 0xD8BFD8
        },
        ui = {
            text = imgui.ImVec4(1.00, 1.00, 1.00, 0.95),
            
            window_bg = imgui.ImVec4(0.12, 0.08, 0.20, 0.92),
            child_bg = imgui.ImVec4(0.15, 0.10, 0.25, 0.88),
            
            border = imgui.ImVec4(0.30, 0.20, 0.45, 0.50),
            
            frame_bg = imgui.ImVec4(0.20, 0.15, 0.30, 0.75),
            frame_hover = imgui.ImVec4(0.25, 0.20, 0.40, 0.80),
            frame_active = imgui.ImVec4(0.35, 0.25, 0.50, 0.90),
            
            button = imgui.ImVec4(0.50, 0.20, 0.70, 0.85),
            button_hover = imgui.ImVec4(0.60, 0.25, 0.80, 0.95),
            button_active = imgui.ImVec4(0.70, 0.30, 0.90, 1.00),
            
            header = imgui.ImVec4(0.40, 0.20, 0.60, 0.80),
            header_hover = imgui.ImVec4(0.50, 0.25, 0.70, 0.85),
            
            separator = imgui.ImVec4(0.50, 0.25, 0.80, 0.60),
            
            accent = imgui.ImVec4(0.80, 0.30, 1.00, 1.00),
            success = imgui.ImVec4(0.30, 0.80, 0.30, 1.00),
            error = imgui.ImVec4(0.90, 0.20, 0.20, 1.00),
            warning = imgui.ImVec4(1.00, 0.70, 0.00, 1.00)
        }
    },
    
    dark_green = {
        name = "Зеленый",
        chat_colors = {
            header = 0x32CD32,
            box_bg = 0x1B3C2D,
            border = 0x2B6C4A,
            text = 0xFFFFFF,
            accent = 0x32CD32,
            success = 0x00FF00,
            error = 0xFF4444,
            warning = 0xFFA500,
            info = 0x90EE90
        },
        ui = {
            text = imgui.ImVec4(1.00, 1.00, 1.00, 0.95),
            
            window_bg = imgui.ImVec4(0.08, 0.15, 0.12, 0.92),
            child_bg = imgui.ImVec4(0.10, 0.18, 0.15, 0.88),
            
            border = imgui.ImVec4(0.20, 0.35, 0.25, 0.50),
            
            frame_bg = imgui.ImVec4(0.15, 0.25, 0.20, 0.75),
            frame_hover = imgui.ImVec4(0.20, 0.35, 0.25, 0.80),
            frame_active = imgui.ImVec4(0.25, 0.45, 0.30, 0.90),
            
            button = imgui.ImVec4(0.20, 0.60, 0.30, 0.85),
            button_hover = imgui.ImVec4(0.25, 0.70, 0.35, 0.95),
            button_active = imgui.ImVec4(0.30, 0.80, 0.40, 1.00),
            
            header = imgui.ImVec4(0.25, 0.50, 0.35, 0.80),
            header_hover = imgui.ImVec4(0.30, 0.60, 0.40, 0.85),
            
            separator = imgui.ImVec4(0.30, 0.60, 0.40, 0.60),
            
            accent = imgui.ImVec4(0.00, 0.90, 0.50, 1.00),
            success = imgui.ImVec4(0.00, 0.80, 0.30, 1.00),
            error = imgui.ImVec4(0.90, 0.20, 0.20, 1.00),
            warning = imgui.ImVec4(1.00, 0.70, 0.00, 1.00)
        }
    }
}

-- ================== УВЕДОМЛЕНИЯ ==================
local function show_chat_notification(type, title, message)
    if not config.show_notifications then return end
    if not message or message == "" then return end
    
    local theme = themes[config.theme] or themes.dark_blue
    local colors = theme.chat_colors
    
    local prefix_color = colors.accent
    if type == "success" then prefix_color = colors.success
    elseif type == "error" then prefix_color = colors.error
    elseif type == "warning" then prefix_color = colors.warning
    elseif type == "info" then prefix_color = colors.info end
    
    local notification_text = "[HOSYACheckActivity] " .. message
    
    local status, err = pcall(function()
        sampAddChatMessage(notification_text, -1)
    end)
    
    if not status then
        pcall(function()
            local converted = u8:decode(notification_text)
            sampAddChatMessage(converted, -1)
        end)
    end
end

-- ================== ЧЕКЕР ==================
local check_error_message = ""
local check_warning_message = ""

local function is_check_time_allowed()
    local current_time = os.date("%H:%M")
    local current_day = tonumber(os.date("%w"))
    if current_day == 0 then current_day = 7 end
    
    if not config.check_days[current_day] then
        return false, "Проверки не разрешены в этот день"
    end

    if current_time < config.check_time_start or current_time > config.check_time_end then
        return false, string.format("Время проверок: %s - %s", config.check_time_start, config.check_time_end)
    end
    
    return true, ""
end

function can_start_check()
    local now = os.time()
    local today = os.date("%Y-%m-%d")
    
    check_error_message = ""
    check_warning_message = ""
    
    -- Убрано ограничение на количество проверок в день
    -- if today_count >= config.max_checks_per_day then
    --     check_error_message = string.format("Достигнут лимит проверок на сегодня: %d/%d", today_count, config.max_checks_per_day)
    --     return false
    -- end

    local time_allowed, time_error = is_check_time_allowed()
    if not time_allowed then
        check_error_message = time_error
        return false
    end
    
    -- Проверка уровня админки (должен быть не менее 3)
    if my_lvl_adm < 3 then
        check_error_message = "СКРИПТ ДОСТУПЕН С 3-ГО УРОВНЯ АДМИНКИ"
        return false
    end
    
    return true
end

function register_check(org_name)
    local now = os.time()
    local check_info = {
        time = now,
        org = org_name,
        date = os.date("%Y-%m-%d %H:%M:%S")
    }
    
    table.insert(check_history, 1, check_info)
    last_check_timestamp = now
    today_checks = today_checks + 1
    
    if #check_history > 100 then
        table.remove(check_history, #check_history)
    end
    
    save_check_history()
    
    show_chat_notification("info", "Проверка начата", 
        string.format("Организация: %s", org_name))
end

function get_check_stats()
    local today = os.date("%Y-%m-%d")
    local today_count = 0
    local last_check_time = ""
    
    for _, check in ipairs(check_history) do
        if os.date("%Y-%m-%d", check.time) == today then
            today_count = today_count + 1
        end
    end
    
    if #check_history > 0 then
        last_check_time = check_history[1].date
    end
    
    return today_count, last_check_time
end

-- ================== ИТОГ ==================
function show_final_report()
    if #spisok_org_members == 0 then return end
    
    local online_count = #spisok_org_members - 1
    local working_count = 0
    local afk_without_esc_count = 0
    local walked_count = 0
    local afk_with_warnings_count = 0
    
    for _, member in ipairs(spisok_org_members) do
        if member.working then
            if member.stats == 2 then 
                working_count = working_count + 1
            elseif member.stats == 3 then 
                afk_without_esc_count = afk_without_esc_count + 1
                if tonumber(member.warns) > 0 then
                    afk_with_warnings_count = afk_with_warnings_count + 1
                end
            elseif member.stats == 5 then 
                walked_count = walked_count + 1
            end
        end
    end
    
    local working_percentage = online_count > 0 and (working_count / online_count) * 100 or 0
    local walked_percentage = online_count > 0 and (walked_count / online_count) * 100 or 0
    local afk_percentage = online_count > 0 and (afk_without_esc_count / online_count) * 100 or 0
    
    local form_points = 0
    if gov_form.leader_online[0] then form_points = form_points + 1 end
    if gov_form.interviews_24h[0] then form_points = form_points + 1 end
    if gov_form.lobby_employee[0] then form_points = form_points + 1 end 

    local org_norm = org_norms[last_orgname] or 8
    local norm_achieved = online_count >= org_norm
    local norm_points = norm_achieved and 1 or 0
    local working_points = working_percentage / 100
    local walked_points = walked_percentage / 100
    local total_points = form_points + working_points + walked_points + norm_points
    local max_total_points = 5 + 1 

    show_chat_notification("success", "Проверка завершена", 
        string.format("Организация: %s | Онлайн: %d | Работают: %d (%.1f%%)", 
            last_orgname, online_count, working_count, working_percentage))
    
    calculate_auto_fields()
    
    if config.auto_save_reports then
        export_to_csv()
    end
end

-- ================== ФОРМА ОТЧЕТНОСТИ ==================
function calculate_auto_fields()
    if #spisok_org_members == 0 then 
        show_chat_notification("warning", "Автозаполнение", "Нет данных для заполнения формы")
        return 
    end
    
    local total_members = #spisok_org_members - 1
    local working_count = 0
    local afk_without_esc_count = 0
    local walked_count = 0
    local total_walked = 0
    local working_in_lobby_count = 0
    local has_leader_or_deputy = false
    
    for _, member in ipairs(spisok_org_members) do
        if member.working then
            if member.stats == 2 then
                working_count = working_count + 1
                working_in_lobby_count = working_in_lobby_count + 1
            elseif member.stats == 3 then
                afk_without_esc_count = afk_without_esc_count + 1
            elseif member.stats == 5 then 
                walked_count = walked_count + 1
            end
        end
        if member.rank_number then
            local rank_num = tonumber(member.rank_number)
            if rank_num == 9 or rank_num == 10 then
                has_leader_or_deputy = true
            end
        end
    end

    total_walked = afk_without_esc_count + walked_count

    local members_str = tostring(total_members)
    ffi.copy(gov_form.members_count, members_str)
    
    local working_str = tostring(working_count)
    ffi.copy(gov_form.working_in_form, working_str)
    
    local afk_str = tostring(total_walked) 
    ffi.copy(gov_form.afk_without_esc, afk_str)

    local walked_with_warnings_count = 0
    for _, member in ipairs(spisok_org_members) do
        if member.working and (member.stats == 3 or member.stats == 5) and tonumber(member.warns) > 0 then
            walked_with_warnings_count = walked_with_warnings_count + 1
        end
    end
    
    local afk_warns_str = tostring(walked_with_warnings_count)
    ffi.copy(gov_form.afk_with_warnings, afk_warns_str)
    
    local work_percentage = total_members > 0 and math.floor((working_count / total_members) * 100) or 0
    local work_str = string.format("%d%% (%d/%d)", work_percentage, working_count, total_members)
    ffi.copy(gov_form.work_with_staff, work_str)

    local walked_percentage = total_members > 0 and math.floor((total_walked / total_members) * 100) or 0
    local walked_str = string.format("%d%% (%d/%d)", walked_percentage, total_walked, total_members)
    ffi.copy(gov_form.work_with_absentees, walked_str)

    local org_norm = org_norms[last_orgname] or 8
    gov_form.members_norm[0] = total_members >= org_norm

    local min_active_achieved = false
    
    if last_orgname == "LSMC" or last_orgname == "LVMC" or last_orgname == "GCL" or last_orgname == "GOV" then
        min_active_achieved = working_in_lobby_count >= 1
    elseif last_orgname == "Fire Department" then
        min_active_achieved = working_in_lobby_count >= 2
    elseif last_orgname == "RCLS" then
        min_active_achieved = working_in_lobby_count >= 1
    elseif last_orgname == "LSPD" or last_orgname == "RCSD" or last_orgname == "SFPD" or 
           last_orgname == "LVPD" or last_orgname == "FBI" then
        min_active_achieved = working_in_lobby_count >= 1
    elseif last_orgname == "LSa" or last_orgname == "SFA" then
        min_active_achieved = working_in_lobby_count >= 2
    else
        min_active_achieved = working_in_lobby_count >= 1
    end
    
    gov_form.min_active[0] = min_active_achieved

    gov_form.lobby_employee[0] = working_in_lobby_count > 0

    gov_form.leader_online[0] = has_leader_or_deputy

    show_chat_notification("success", "Автозаполнение", 
        string.format("Заполнено: онлайн=%d, работают=%d (%d%%), прогулы=%d (%d%%)", 
            total_members, working_count, work_percentage, total_walked, walked_percentage))
    
    if has_leader_or_deputy then
        show_chat_notification("info", "Лидер/зам", "Обнаружен лидер или заместитель в сети")
    end
end

function generate_gov_form_text()
    local total_members = #spisok_org_members - 1
    local working_count = 0
    local afk_without_esc_count = 0
    local walked_count = 0
    local working_in_lobby_count = 0
    
    for _, member in ipairs(spisok_org_members) do
        if member.working then
            if member.stats == 2 then 
                working_count = working_count + 1
                working_in_lobby_count = working_in_lobby_count + 1
            elseif member.stats == 3 then 
                afk_without_esc_count = afk_without_esc_count + 1
            elseif member.stats == 5 then 
                walked_count = walked_count + 1
            end
        end
    end
    
    local total_walked = afk_without_esc_count + walked_count
    
    local org_norm = org_norms[last_orgname] or 8
    local norm_percentage = math.floor((total_members / org_norm) * 100)
    if norm_percentage > 100 then norm_percentage = 100 end

    local work_percentage = total_members > 0 and math.floor((working_count / total_members) * 100) or 0

    local walked_percentage = total_members > 0 and math.floor((total_walked / total_members) * 100) or 0
    
    local point_9_text = org_9th_point[last_orgname] or "Состав выполняет свои обязанности"
    local min_active_text = org_9th_point[last_orgname] or "Минимум-актив достигнут"
    
    local min_active_achieved = false
    
    if last_orgname == "LSMC" or last_orgname == "LVMC" or last_orgname == "GCL" or last_orgname == "GOV" then
        min_active_achieved = working_in_lobby_count >= 1
    elseif last_orgname == "Fire Department" then
        min_active_achieved = working_in_lobby_count >= 2
    elseif last_orgname == "RCLS" then
        min_active_achieved = working_in_lobby_count >= 1
    elseif last_orgname == "LSPD" or last_orgname == "RCSD" or last_orgname == "SFPD" or 
           last_orgname == "LVPD" or last_orgname == "FBI" then
        min_active_achieved = working_in_lobby_count >= 1
    elseif last_orgname == "LSa" or last_orgname == "SFA" then
        min_active_achieved = working_in_lobby_count >= 2
    else
        min_active_achieved = working_in_lobby_count >= 1
    end
    
    local form_text = ""
    form_text = form_text .. "[TABLE width=\"100%\"]\n"
    form_text = form_text .. "[TR]\n"
    form_text = form_text .. "[th][center]Организация[/center][/th]\n"
    form_text = form_text .. "[th][center]Оценка[/center][/th]\n"
    form_text = form_text .. "[th][center]Лидер/зам в сети[/center][/th]\n"
    form_text = form_text .. "[th][center]Собесы за последние 24ч[/center][/th]\n"
    form_text = form_text .. "[th][center]Работа состава[/center][/th]\n"
    form_text = form_text .. "[th][center]Работа с прогульщиками[/center][/th]\n"
    form_text = form_text .. string.format("[th][center]%s[/center][/th]\n", min_active_text)
    form_text = form_text .. "[th][center]Норма /members/a[/center][/th]\n"
    form_text = form_text .. "[/TR]\n"

    local form_points = 0

    if gov_form.interviews_24h[0] then form_points = form_points + 1 end
    if gov_form.lobby_employee[0] then form_points = form_points + 1 end
    if gov_form.leader_online[0] then form_points = form_points + 1 end

    local work_points = work_percentage / 100
    local walked_points = walked_percentage / 100
    local norm_points = total_members >= org_norm and 1 or 0
    local total_points = form_points + norm_points + work_points + walked_points
    
    local leader_online_text = gov_form.leader_online[0] and "Да" or "Нет"
    local interviews_text = gov_form.interviews_24h[0] and "Да" or "Нет"
    local min_active_text_result = min_active_achieved and "Да" or "Нет"
    
    form_text = form_text .. string.format("[TR][td][center]%s[/center][/td]\n", last_orgname)
    form_text = form_text .. string.format("[td][center]%.1f/5[/center][/td]\n", total_points)
    form_text = form_text .. string.format("[td][center]%s[/center][/td]\n", leader_online_text)
    form_text = form_text .. string.format("[td][center]%s[/center][/td]\n", interviews_text)
    form_text = form_text .. string.format("[td][center]%s[/center][/td]\n",
        string.format("%d%% (%d/%d)", work_percentage, working_count, total_members))
    form_text = form_text .. string.format("[td][center]%s[/center][/td]\n",
        string.format("%d%% (%d/%d)", walked_percentage, total_walked, total_members))
    form_text = form_text .. string.format("[td][center]%s (%d работающих)[/center][/td]\n",
        min_active_text_result, working_in_lobby_count)
    form_text = form_text .. string.format("[td][center]%d%% (%d/%d)[/center][/td]\n",
        norm_percentage, total_members, org_norm)
    form_text = form_text .. "[/TR]\n"
    form_text = form_text .. "[/TABLE]"
    
    return form_text
end

function update_animations()
    local speed = 8.0
    
    local windows = {
        {renderWindow, "main_window_alpha"},
        {renderSettingsWindow, "settings_window_alpha"},
        {renderMembersWindow, "check_window_alpha"},
        {renderGovFormWindow, "gov_form_alpha"},
        {renderUpdateWindow, "update_window_alpha"}
    }
    
    for _, win in ipairs(windows) do
        if win[1][0] then
            animation_values[win[2]] = animation_values[win[2]] + (1 - animation_values[win[2]]) * speed * 0.016
        else
            animation_values[win[2]] = animation_values[win[2]] + (0 - animation_values[win[2]]) * speed * 0.016
        end
    end
end

-- ================== ЗАГРУЗКА СОТРУДНИКОВ ==================
local function start_loading_members(org_name)
    if loading_members then return end
    
    loading_members = true
    loading_progress = "Загрузка данных"
    loading_dots = ""
    loading_last_update = os.clock()
    check_members = true
    spisok_org_members = {}
    
    sampSendChat("/members")
    
    show_chat_notification("info", "Начата загрузка", 
        string.format("Загружаем список сотрудников: %s", org_name))
    
    lua_thread.create(function()
        wait(30000)
        if loading_members then
            loading_members = false
            check_members = false
            show_chat_notification("error", "Таймаут загрузки", 
                "Не удалось загрузить данные организации")
        end
    end)
end

-- ================== КОНФИГУРАЦИЯ ==================
function load_config()
    local file = io.open(config_file, "r")
    if file then
        local content = file:read("*a")
        file:close()
        
        if content and content ~= "" then
            config.theme = content:match('"theme"%s*:%s*"([^"]*)"') or "dark_blue"
            config.auto_save_reports = content:match('"auto_save_reports"%s*:%s*(%a+)') == "true"
            config.show_notifications = content:match('"show_notifications"%s*:%s*(%a+)') ~= "false"
            config.notification_duration = tonumber(content:match('"notification_duration"%s*:%s*(%d+)')) or 5
            config.check_time_start = content:match('"check_time_start"%s*:%s*"([^"]*)"') or "19:00"
            config.check_time_end = content:match('"check_time_end"%s*:%s*"([^"]*)"') or "21:00"
            config.check_organization = content:match('"check_organization"%s*:%s*"([^"]*)"') or "LSPD"
            config.enable_check_reminders = content:match('"enable_check_reminders"%s*:%s*(%a+)') ~= "false"
            config.max_checks_per_day = 999 -- Убрано ограничение
            config.last_check_date = content:match('"last_check_date"%s*:%s*"([^"]*)"') or ""
            config.last_check_org = content:match('"last_check_org"%s*:%s*"([^"]*)"') or ""
            config.reminder_interval_minutes = tonumber(content:match('"reminder_interval_minutes"%s*:%s*(%d+)')) or 5
            config.auto_check_updates = content:match('"auto_check_updates"%s*:%s*(%a+)') ~= "false" -- Новая настройка
            
            for i = 1, 7 do
                local day = content:match('"check_day_' .. i .. '"%s*:%s*(%a+)')
                config.check_days[i] = day ~= "false"
            end
            auto_save_reports_bool[0] = config.auto_save_reports
            show_notifications_bool[0] = config.show_notifications
            enable_check_reminders_bool[0] = config.enable_check_reminders
            max_checks_input[0] = config.max_checks_per_day
            auto_check_updates_bool[0] = config.auto_check_updates
            
            ffi.copy(check_time_start_input, config.check_time_start)
            ffi.copy(check_time_end_input, config.check_time_end)
            ffi.copy(check_org_input, config.check_organization)
            
            for i = 1, 7 do
                check_days_bools[i][0] = config.check_days[i]
            end
        end
    end
end

function save_config()
    local days_json = ""
    for i = 1, 7 do
        days_json = days_json .. string.format('    "check_day_%d": %s,\n', i, config.check_days[i] and "true" or "false")
    end
    
    local data = string.format([[{
    "theme": "%s",
    "auto_save_reports": %s,
    "show_notifications": %s,
    "notification_duration": %d,
    "check_time_start": "%s",
    "check_time_end": "%s",
    "check_organization": "%s",
    "enable_check_reminders": %s,
    "max_checks_per_day": %d,
    "last_check_date": "%s",
    "last_check_org": "%s",
    "reminder_interval_minutes": %d,
    "auto_check_updates": %s,
%s
    "version": "1.1"
}
]], 
        config.theme,
        tostring(config.auto_save_reports),
        tostring(config.show_notifications),
        config.notification_duration,
        config.check_time_start,
        config.check_time_end,
        config.check_organization,
        tostring(config.enable_check_reminders),
        config.max_checks_per_day,
        config.last_check_date,
        config.last_check_org,
        config.reminder_interval_minutes,
        tostring(config.auto_check_updates),
        days_json:sub(1, -3)
    )
    
    local file = io.open(config_file, "w")
    if file then
        file:write(data)
        file:close()
        return true
    end
    return false
end

function save_check_history()
    local file = io.open("hosya_check_history.json", "w")
    if file then
        local data = "["
        for i, check in ipairs(check_history) do
            if i > 1 then data = data .. "," end
            data = data .. string.format('{"time":%d,"org":"%s","date":"%s"}',
                check.time, check.org, check.date)
        end
        data = data .. "]"
        file:write(data)
        file:close()
    end
end

function load_check_history()
    local file = io.open("hosya_check_history.json", "r")
    if file then
        local content = file:read("*a")
        file:close()
        
        if content and content ~= "" then
            check_history = {}
            for check_str in content:gmatch('{[^}]+}') do
                local time = check_str:match('"time":(%d+)')
                local org = check_str:match('"org":"([^"]+)"')
                local date = check_str:match('"date":"([^"]+)"')
                
                if time and org and date then
                    table.insert(check_history, {
                        time = tonumber(time),
                        org = org,
                        date = date
                    })
                end
            end
            
            if #check_history > 0 then
                table.sort(check_history, function(a, b) return a.time > b.time end)
                last_check_timestamp = check_history[1].time
            end
        end
    end
end

function save_report_history()
    local file = io.open("hosya_report_history.json", "w")
    if file then
        local data = "["
        for i, report in ipairs(report_history) do
            if i > 1 then data = data .. "," end
            data = data .. string.format('{"date":"%s","org":"%s","filename":"%s","total_members":%d}',
                report.date, report.org, report.filename, report.total_members)
        end
        data = data .. "]"
        file:write(data)
        file:close()
    end
end

function load_report_history()
    local file = io.open("hosya_report_history.json", "r")
    if file then
        local content = file:read("*a")
        file:close()
        
        if content and content ~= "" then
            report_history = {}
            for report_str in content:gmatch('{[^}]+}') do
                local date = report_str:match('"date":"([^"]+)"')
                local org = report_str:match('"org":"([^"]+)"')
                local filename = report_str:match('"filename":"([^"]+)"')
                local total = report_str:match('"total_members":(%d+)')
                
                if date and org and filename and total then
                    table.insert(report_history, {
                        date = date,
                        org = org,
                        filename = filename,
                        total_members = tonumber(total)
                    })
                end
            end
            
            table.sort(report_history, function(a, b) 
                return a.date > b.date 
            end)
        end
    else
        report_history = {}
    end
end

-- ================== ЭКСПОРТ ОТЧЕТОВ ==================
function export_to_csv()
    if #spisok_org_members == 0 then
        show_chat_notification("error", "Ошибка экспорта", "Нет данных для экспорта")
        return false, "Нет данных для экспорта"
    end
    local inForm, inFormVIG, afkBezEscInForm, afkBezEscInFormVIG, walkedInFormInForm, walkedInFormInFormVIG = 0, 0, 0, 0, 0, 0
    local working_in_lobby_count = 0
    local has_leader_or_deputy = false
    local status_counts = {0, 0, 0, 0, 0}
    
    for i, v in ipairs(spisok_org_members) do
        if v.working then 
            inForm = inForm + 1
            if tonumber(v.warns) > 0 then
                inFormVIG = inFormVIG + 1
            end
            if v.stats == 3 then
                afkBezEscInForm = afkBezEscInForm + 1
                if tonumber(v.warns) > 0 then
                    afkBezEscInFormVIG = afkBezEscInFormVIG + 1
                end
            elseif v.stats == 5 then
                walkedInFormInForm = walkedInFormInForm + 1
                if tonumber(v.warns) > 0 then
                    walkedInFormInFormVIG = walkedInFormInFormVIG + 1
                end
            end

            if v.stats == 2 then
                working_in_lobby_count = working_in_lobby_count + 1
            end
        end
        if v.stats >= 1 and v.stats <= 5 then
            status_counts[v.stats] = status_counts[v.stats] + 1
        end
        if v.rank_number and (tonumber(v.rank_number) == 9 or tonumber(v.rank_number) == 10) then
            has_leader_or_deputy = true
        end
    end

    local total_members = #spisok_org_members - 1
    local org_norm = org_norms[last_orgname] or 8
    local work_percentage = total_members > 0 and math.floor((inForm / total_members) * 100) or 0
    local total_walked = afkBezEscInForm + walkedInFormInForm
    local walked_percentage = total_members > 0 and math.floor((total_walked / total_members) * 100) or 0
    local norm_percentage = math.floor((total_members / org_norm) * 100)
    if norm_percentage > 100 then norm_percentage = 100 end

    local csv_data = ""

    csv_data = csv_data .. ru("Дата;Организация;Начало проверки;Конец проверки;Всего сотрудников;В форме;Из них с выговорами;АФК без ЕСК;Из них с выговорами;Прогульщиков;Из них с выговорами\n")
    csv_data = csv_data .. string.format("%s;%s;%s;%s;%d;%d;%d;%d;%d;%d;%d\n\n",
        os.date("%Y-%m-%d %H:%M:%S"),
        last_orgname or "Неизвестно",
        last_time_check_members or "Неизвестно",
        last_time_stop_check_members or "Неизвестно",
        total_members,
        inForm,
        inFormVIG,
        afkBezEscInForm,
        afkBezEscInFormVIG,
        walkedInFormInForm,
        walkedInFormInFormVIG
    )

    csv_data = csv_data .. ru("СТАТИСТИКА\n")
    csv_data = csv_data .. string.format(ru("Процент работающих: %d%%\n"), work_percentage)
    csv_data = csv_data .. string.format(ru("Процент прогульщиков: %d%%\n"), walked_percentage)
    csv_data = csv_data .. string.format(ru("Норма сотрудников: %d/%d (%d%%)\n"), total_members, org_norm, norm_percentage)
    csv_data = csv_data .. string.format(ru("Лидер/зам в сети: %s\n"), has_leader_or_deputy and ru("Да") or ru("Нет"))
    csv_data = csv_data .. string.format(ru("Работающих в лобби/на точке: %d\n"), working_in_lobby_count)
    csv_data = csv_data .. "\n"
    
    csv_data = csv_data .. ru("ОТЧЕТ\n")
    csv_data = csv_data .. string.format(ru("Построение/сбор на тренировку: %s\n"), gov_form.training_building[0] and ru("Да") or ru("Нет"))
    csv_data = csv_data .. string.format(ru("Собеседования за 24ч: %s\n"), gov_form.interviews_24h[0] and ru("Да") or ru("Нет"))
    csv_data = csv_data .. string.format(ru("Лидер/зам в сети: %s\n"), gov_form.leader_online[0] and ru("Да") or ru("Нет"))
    
    local point_9_text = org_9th_point[last_orgname] or ru("Состав выполняет свои обязанности")
    csv_data = csv_data .. string.format("%s: %s\n", point_9_text, gov_form.lobby_employee[0] and ru("Да") or ru("Нет"))

    local min_active_achieved = false
    local min_active_text = org_9th_point[last_orgname] or ru("Минимум-актив достигнут")
    
    if last_orgname == "LSMC" or last_orgname == "LVMC" or last_orgname == "GCL" or last_orgname == "GOV" then
        min_active_achieved = working_in_lobby_count >= 1
    elseif last_orgname == "Fire Department" then
        min_active_achieved = working_in_lobby_count >= 2
    elseif last_orgname == "RCLS" then
        min_active_achieved = working_in_lobby_count >= 1
    elseif last_orgname == "LSPD" or last_orgname == "RCSD" or last_orgname == "SFPD" or 
           last_orgname == "LVPD" or last_orgname == "FBI" then
        min_active_achieved = working_in_lobby_count >= 1
    elseif last_orgname == "LSa" or last_orgname == "SFA" then
        min_active_achieved = working_in_lobby_count >= 2
    else
        min_active_achieved = working_in_lobby_count >= 1
    end
    
    csv_data = csv_data .. string.format("%s: %s\n", min_active_text, min_active_achieved and ru("Да") or ru("Нет"))
    csv_data = csv_data .. string.format(ru("Норма /members/a соблюдена: %s\n"), total_members >= org_norm and ru("Да") or ru("Нет"))

    local form_points = 0
    if gov_form.interviews_24h[0] then form_points = form_points + 1 end
    if gov_form.lobby_employee[0] then form_points = form_points + 1 end
    if gov_form.leader_online[0] then form_points = form_points + 1 end

    local work_points = work_percentage / 100
    local walked_points = walked_percentage / 100
    local norm_points = total_members >= org_norm and 1 or 0
    local total_points = form_points + norm_points + work_points + walked_points
    
    csv_data = csv_data .. string.format(ru("Общая оценка: %.1f/5\n"), total_points)
    csv_data = csv_data .. string.format(ru("Формальные пункты: %.1f/5\n"), form_points)
    csv_data = csv_data .. string.format(ru("Работа состава: %.2f/1\n"), work_points)
    csv_data = csv_data .. string.format(ru("Работа с прогульщиками: %.2f/1\n"), walked_points)
    csv_data = csv_data .. string.format(ru("Норма сотрудников: %.1f/1\n"), norm_points)
    csv_data = csv_data .. "\n"
    
    csv_data = csv_data .. ru("ПО СТАТУСАМ\n")
    for i = 1, #status_members do
        csv_data = csv_data .. string.format("%s: %d (%.1f%%)\n", 
             ru(status_members[i]), 
            status_counts[i], 
            total_members > 0 and (status_counts[i] / total_members) * 100 or 0)
    end
    csv_data = csv_data .. "\n"
    csv_data = csv_data .. ru("Ник;ID;Ранг;Выговоры;Статус;В форме;Ранг №;Примечание\n")
    
    for i, v in ipairs(spisok_org_members) do
        local status_text = status_members[v.stats]
        local note = ""
        
        if tonumber(v.warns) > 0 then
            note = note .. ru("Выговор(" .. v.warns .. "/3) ")
        end
        
        if v.rank_number and (tonumber(v.rank_number) == 9 or tonumber(v.rank_number) == 10) then
            note = note .. ru("Лидер/зам ")
        end
        
        if v.stats == 3 then
            note = note .. ru("АФК без ЕСК")
        elseif v.stats == 5 then
            note = note .. ru("Прогул")
        end
        
        csv_data = csv_data .. string.format("%s;%s;%s;%s;%s;%s;%s;%s\n",
            v.nick, 
            v.id, 
            v.rank, 
            v.warns,
            status_text,
            v.working and ru("Да") or ru("Нет"),
            v.rank_number or "0",
            note
        )
    end
    
    local folder = "hosya_reports"
    os.execute('mkdir "' .. folder .. '" 2>nul')
    
    local safe_orgname = (last_orgname or "unknown"):gsub("[^%w_]", "_")
    local filename = folder .. "/" .. os.date("%Y%m%d_%H%M%S") .. "_" .. safe_orgname .. ".csv"
    
    local file = io.open(filename, "w")
    if file then
        local encoded_data = u8:decode(csv_data)
        file:write(encoded_data)
        file:close()

        table.insert(report_history, 1, {
            date = os.date("%Y-%m-%d %H:%M:%S"),
            org = last_orgname,
            filename = filename,
            total_members = total_members
        })
        
        if #report_history > 50 then
            table.remove(report_history, #report_history)
        end
        
        save_report_history()
        
        config.last_check_date = os.date("%Y-%m-%d %H:%M:%S")
        config.last_check_org = last_orgname
        save_config()
        
        show_chat_notification("success", "Экспорт завершен", 
            "Данные сохранены в: " .. filename .. "\n")
        
        return true, "Данные сохранены в: " .. filename .. "\n"
    end
    
    return false, "Ошибка сохранения файла"
end

function next_employee()
    if corrent_id_to_rec < #spisok_org_members then
        corrent_id_to_rec = corrent_id_to_rec + 1
        sampSendChat('/re ' .. spisok_org_members[corrent_id_to_rec].id)
        
        if corrent_id_to_rec % 10 == 0 then
            show_chat_notification("info", "Прогресс проверки", 
                string.format("Проверено %d из %d сотрудников", corrent_id_to_rec - 1, #spisok_org_members))
        end
    else
        renderMembersWindow[0] = false
        renderWindow[0] = true
        check_status_members = false
        last_time_stop_check_members = os.date('%H:%M:%S')
        
        show_chat_notification("success", "Проверка завершена", 
            string.format("Проверка организации '%s' завершена", last_orgname))

        show_final_report()
    end
end

-- ================== ЛВЛ ==================
local check_admin_timer = 0
local check_admin_attempts = 0
local max_admin_attempts = 5

local function check_admin_level_on_start()
    lua_thread.create(function()
        wait(1000)
        
        local is_spawned = false
        local status, result = pcall(sampIsLocalPlayerSpawned)
        if status then
            is_spawned = result
        end
        
        if not is_spawned then
            show_chat_notification("warning", "Админка не проверена", 
                "Игрок не заспавнен. Проверка отменена.")
            return
        end
        
        check_my_lvl_adm = true
        
        local success = pcall(function()
            sampSendChat('/apanel')
        end)
        
        if not success then
            check_my_lvl_adm = false
            show_chat_notification("warning", "Ошибка проверки", 
                "Не удалось отправить команду /apanel")
            return
        end

        wait(1000)
        
        if check_my_lvl_adm then
            check_my_lvl_adm = false
            for _, dialogId in ipairs({27090, 8310, 8311, 8312}) do
                pcall(function()
                    sampSendDialogResponse(dialogId, 0, -1, "")
                end)
            end
        end
    end)
end

local function check_admin_level_click()
    show_chat_notification("info", "Проверка уровня", "Определение уровня админки...")
    
    lua_thread.create(function()
        wait(1000)
        
        local is_spawned = false
        local status, result = pcall(sampIsLocalPlayerSpawned)
        if status then
            is_spawned = result
        end
        
        if not is_spawned then
            show_chat_notification("warning", "Админка не проверена", 
                "Игрок не заспавнен. Проверка отменена.")
            return
        end
        
        check_my_lvl_adm = true
        
        local success = pcall(function()
            sampSendChat('/apanel')
        end)
        
        if not success then
            check_my_lvl_adm = false
            show_chat_notification("warning", "Ошибка проверки", 
                "Не удалось отправить команду /apanel")
            return
        end

        wait(1000)
        
        if check_my_lvl_adm then
            check_my_lvl_adm = false
            for _, dialogId in ipairs({27090, 8310, 8311, 8312}) do
                pcall(function()
                    sampSendDialogResponse(dialogId, 0, -1, "")
                end)
            end
        end
    end)
end

-- ================== ОКНО ОБНОВЛЕНИЙ ==================
local updateFrame = imgui.OnFrame(
    function() return renderUpdateWindow[0] end,
    function()
        update_animations()
        
        local theme = themes[config.theme] or themes.dark_blue
        local ui_theme = theme.ui
        
        imgui.SetNextWindowBgAlpha(animation_values.update_window_alpha)
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(600, 450))
        
        imgui.Begin(ru("Обновление скрипта"), renderUpdateWindow, imgui.WindowFlags.NoResize)
        
        imgui.TextColored(ui_theme.accent, ru("Система обновлений HOSYACheckActivity"))
        imgui.Separator()
        
        -- Текущая версия
        imgui.Text(ru("Текущая версия: ") .. current_version)
        
        -- Последняя версия
        imgui.Text(ru("Последняя версия: ") .. latest_version)
        
        -- Статус
        imgui.TextColored(ui_theme.accent, ru("Статус: "))
        imgui.SameLine()
        
        if is_checking_update then
            imgui.TextColored(ui_theme.warning, ru(update_status))
        elseif update_available then
            imgui.TextColored(ui_theme.success, ru(update_status))
        else
            imgui.Text(ru(update_status))
        end
        
        imgui.Separator()
        
        -- Changelog если есть
        if update_changelog ~= "" then
            imgui.TextColored(ui_theme.accent, ru("Изменения в новой версии:"))
            imgui.BeginChild(ru("Changelog"), imgui.ImVec2(0, 150), true)
            imgui.TextWrapped(ru(update_changelog))
            imgui.EndChild()
        end
        
        imgui.Separator()
        
        -- Прогресс бар при загрузке
        if is_downloading then
            imgui.ProgressBar(update_progress / 100, imgui.ImVec2(-1, 20))
            imgui.Text(ru(update_status))
        end
        
        -- Кнопки
        imgui.BeginGroup()
        
        if not is_downloading then
            if imgui.Button(ru("Проверить обновления"), imgui.ImVec2(180, 40)) then
                check_for_updates()
            end
            
            imgui.SameLine()
            
            if update_available and not is_checking_update then
                if imgui.Button(ru("Установить обновление"), imgui.ImVec2(180, 40)) then
                    download_update()
                end
            else
                imgui.PushStyleVar(imgui.StyleVar.Alpha, 0.5)
                imgui.Button(ru("Установить обновление"), imgui.ImVec2(180, 40))
                imgui.PopStyleVar()
            end
            
            imgui.SameLine()
            
            if imgui.Button(ru("Закрыть"), imgui.ImVec2(80, 40)) then
                renderUpdateWindow[0] = false
            end
        else
            -- При загрузке показываем только кнопку отмены (в этом примере отмена не реализована)
            imgui.PushStyleVar(imgui.StyleVar.Alpha, 0.5)
            imgui.Button(ru("Отмена"), imgui.ImVec2(180, 40))
            imgui.PopStyleVar()
        end
        
        imgui.EndGroup()
        
        imgui.Spacing()
        
        -- Информация
        imgui.TextColored(imgui.ImVec4(0.7, 0.7, 0.7, 1), 
            ru("После установки обновления нажмите F5 для перезагрузки скрипта"))
        
        imgui.End()
    end
)

-- ================== ОСНОВНОЕ ОКНО ==================
local mainFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function()
        update_animations()
        
        local theme = themes[config.theme] or themes.dark_blue
        local ui_theme = theme.ui
        
        imgui.SetNextWindowBgAlpha(animation_values.main_window_alpha)
        
        local style = imgui.GetStyle()
        style.WindowPadding = imgui.ImVec2(15, 15)
        style.WindowRounding = 12.0
        style.FramePadding = imgui.ImVec2(10, 6)
        style.FrameRounding = 8.0
        style.ItemSpacing = imgui.ImVec2(10, 8)
        style.ItemInnerSpacing = imgui.ImVec2(8, 6)
        style.ScrollbarSize = 14.0
        style.ScrollbarRounding = 8.0
        
        for i = 0, imgui.Col.COUNT-1 do
            style.Colors[i] = ui_theme.window_bg
        end
        
        style.Colors[imgui.Col.Text] = ui_theme.text
        style.Colors[imgui.Col.WindowBg] = ui_theme.window_bg
        style.Colors[imgui.Col.ChildBg] = ui_theme.child_bg
        style.Colors[imgui.Col.Border] = ui_theme.border
        style.Colors[imgui.Col.FrameBg] = ui_theme.frame_bg
        style.Colors[imgui.Col.FrameBgHovered] = ui_theme.frame_hover
        style.Colors[imgui.Col.FrameBgActive] = ui_theme.frame_active
        style.Colors[imgui.Col.Button] = ui_theme.button
        style.Colors[imgui.Col.ButtonHovered] = ui_theme.button_hover
        style.Colors[imgui.Col.ButtonActive] = ui_theme.button_active
        style.Colors[imgui.Col.Header] = ui_theme.header
        style.Colors[imgui.Col.HeaderHovered] = ui_theme.header_hover
        style.Colors[imgui.Col.Separator] = ui_theme.separator
        
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(1200, 850), imgui.Cond.FirstUseEver)
        
        imgui.Begin(ru("HOSYACheckActivity"), renderWindow, imgui.WindowFlags.NoCollapse)
        
        -- Проверка доступности скрипта
        local script_available = my_lvl_adm >= 3
        
        local today_checks_count, last_check_time = get_check_stats()
        imgui.TextColored(ui_theme.accent, ru("HOSYACheckActivity"))
        
        if not script_available and my_lvl_adm > 0 then
            imgui.SameLine(0, 20)
            imgui.TextColored(ui_theme.error, ru("СКРИПТ ДОСТУПЕН С 3-ГО УРОВНЯ АДМИНКИ"))
        end
        
        imgui.SameLine(0, 20)
        imgui.TextColored(imgui.ImVec4(0.7, 0.7, 0.7, 1), ru("Последняя: ") .. (last_check_time ~= "" and last_check_time or "не было"))

        imgui.SameLine(0, 20)
        local admin_text = ru("Твой уровень админки: ") .. (my_lvl_adm > 0 and tostring(my_lvl_adm) or ru("Не определен"))
        local admin_color = script_available and ui_theme.success or (my_lvl_adm > 0 and ui_theme.error or imgui.ImVec4(0.7, 0.7, 0.7, 1))
        imgui.TextColored(admin_color, admin_text)
        
        if imgui.IsItemClicked() then
            check_admin_level_click()
        end
        
        imgui.SameLine(0, 20)
        imgui.TextColored(imgui.ImVec4(0.5, 0.8, 1.0, 1.0), ru("Сейчас ты устроен в ") .. ru(last_orgname))
        
        -- Иконка обновления если доступно
        if update_available and not is_checking_update then
            imgui.SameLine(0, 20)
            imgui.TextColored(ui_theme.success, ru("?? Доступно обновление!"))
            if imgui.IsItemClicked() then
                renderUpdateWindow[0] = true
            end
        end
        
        imgui.Separator()

        imgui.BeginChild(ru("Navigation"), imgui.ImVec2(200, 0), true)
        
        imgui.PushStyleColor(imgui.Col.Button, ui_theme.accent)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(
            ui_theme.accent.x + 0.1, ui_theme.accent.y + 0.1, ui_theme.accent.z + 0.1, 1))
        
        if imgui.Button(ru("Проверка активности"), imgui.ImVec2(-1, 45)) then 
            page = 2 
        end
        imgui.Spacing()
        
        if imgui.Button(ru("Отчеты"), imgui.ImVec2(-1, 45)) then 
            page = 3 
        end
        imgui.Spacing()
        
        if imgui.Button(ru("Форма отчетности"), imgui.ImVec2(-1, 45)) then 
            if script_available then
                renderGovFormWindow[0] = true 
            else
                show_chat_notification("error", "Доступ запрещен", "СКРИПТ ДОСТУПЕН С 3-ГО УРОВНЯ АДМИНКИ")
            end
        end
        imgui.Spacing()
        
        if imgui.Button(ru("Настройки"), imgui.ImVec2(-1, 45)) then 
            if script_available then
                renderSettingsWindow[0] = true 
            else
                show_chat_notification("error", "Доступ запрещен", "СКРИПТ ДОСТУПЕН С 3-ГО УРОВНЯ АДМИНКИ")
            end
        end
        imgui.Spacing()
        
        -- Кнопка Обновления
        if imgui.Button(ru("Обновления"), imgui.ImVec2(-1, 45)) then 
            renderUpdateWindow[0] = true
        end
        
        imgui.Spacing()
        
        if imgui.Button(ru("Информация"), imgui.ImVec2(-1, 45)) then 
            page = 4 
        end
        
        imgui.PopStyleColor(2)
        
        imgui.EndChild()
        
        imgui.SameLine()
        
        imgui.BeginChild(ru("Content"), imgui.ImVec2(0, 0), true)
        
        if page == 2 then
            imgui.TextColored(ui_theme.accent, ru("Проверка активности организации"))
            imgui.Separator()
            
            local can_check = can_start_check()
            local time_allowed, time_error = is_check_time_allowed()
            local status_color = can_check and ui_theme.success or ui_theme.warning
            local status_text = can_check and ru("Можно начинать проверку") or ru("Проверка временно недоступна")
            
            imgui.TextColored(status_color, status_text)
            
            if not time_allowed then
                imgui.TextColored(ui_theme.warning, ru(time_error))
            end
            
            if check_error_message ~= "" then
                imgui.TextColored(ui_theme.error, ru(check_error_message))
            end
            
            imgui.Spacing()
            
            imgui.Text(ru("Выберите организацию для вступления (для 3 лвл и ниже отправится форма):"))
            if imgui.BeginCombo(ru("##org_select"), selected_org_name) then
                for i, org_name in ipairs(org_id) do
                    if org_name ~= "" then
                        if imgui.Selectable(ru(org_name), i == selected_org) then
                            selected_org = i
                            selected_org_name = ru(org_name)
                        end
                    end
                end
                imgui.EndCombo()
            end

            imgui.Spacing()

            if imgui.Button(ru("Устроиться"), imgui.ImVec2(150, 35)) then
                if selected_org_name ~= ru("Выберите организацию") then
                    local result, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
                    if result then
                        if my_lvl_adm <= 3 then
                            sampSendChat(string.format("/a /setmember %d %s 3 admin", id, selected_org))
                            show_chat_notification("info", "Устройство", 
                                string.format("Запрос на устройство в %s отправлен", org_id[selected_org]))
                        elseif my_lvl_adm > 0 then
                            sampSendChat(string.format("/setmember %d %s 3 admin", id, selected_org))
                            show_chat_notification("info", "Устройство", 
                                string.format("Запрос на устройство в %s отправлен", org_id[selected_org]))
                        else
                            show_chat_notification("error", "Ошибка", 
                                "Не удалось определить ваш ID")
                        end
                    end
                else
                    show_chat_notification("warning", "Выбор организации", 
                        "Сначала выберите организацию из списка")
                end
            end
            
            imgui.SameLine()

            local button_text = loading_members and ru("Загрузка") .. loading_dots or ru("Загрузить /members")
            local button_enabled = not loading_members and selected_org_name ~= ru("Выберите организацию") and script_available
            
            if not button_enabled then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.5, 0.5, 0.5, 0.5))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.5, 0.5, 0.5, 0.5))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.5, 0.5, 0.5, 0.5))
                imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.7, 0.7, 0.7, 0.7))
            end
            
            if imgui.Button(button_text, imgui.ImVec2(150, 35)) then
                if button_enabled then
                    last_time_check_members = os.date('%H:%M:%S')
                    local org_name = org_id[selected_org]
                    start_loading_members(org_name)
                elseif not script_available then
                    show_chat_notification("error", "Доступ запрещен", 
                        "СКРИПТ ДОСТУПЕН С 3-ГО УРОВНЯ АДМИНКИ")
                end
            end
            
            if not button_enabled then
                imgui.PopStyleColor(4)
            end

            if loading_members then
                imgui.SameLine()
                imgui.TextColored(ui_theme.accent, ru(loading_progress .. loading_dots))
            end
            
            imgui.Spacing()
            
            if #spisok_org_members > 0 then
                local stats_inForm, stats_inFormVIG, stats_afkBezEscInForm, stats_afkBezEscInFormVIG, 
                      stats_walkedInFormInForm, stats_walkedInFormInFormVIG = 0, 0, 0, 0, 0, 0
                
                for i, v in ipairs(spisok_org_members) do
                    if v.working then 
                        stats_inForm = stats_inForm + 1
                        if tonumber(v.warns) > 0 then
                            stats_inFormVIG = stats_inFormVIG + 1
                        end
                        if v.stats == 3 then
                            stats_afkBezEscInForm = stats_afkBezEscInForm + 1
                            if tonumber(v.warns) > 0 then
                                stats_afkBezEscInFormVIG = stats_afkBezEscInFormVIG + 1
                            end
                        elseif v.stats == 5 then
                            stats_walkedInFormInForm = stats_walkedInFormInForm + 1
                            if tonumber(v.warns) > 0 then
                                stats_walkedInFormInFormVIG = stats_walkedInFormInFormVIG + 1
                            end
                        end
                    end
                end
                
                imgui.Text(ru(string.format("Организация: %s | Начало: %s | Конец: %s", 
                    last_orgname, last_time_check_members, last_time_stop_check_members)))
                
                imgui.Spacing()
                
                imgui.BeginGroup()
                
                if can_start_check() then
                    if imgui.Button(ru("Начать проверку"), imgui.ImVec2(170, 45)) then
                        if #spisok_org_members > 0 then
                            check_status_members = true
                            renderMembersWindow[0] = true
                            renderWindow[0] = false
                            corrent_id_to_rec = 1
                            sampSendChat('/re ' .. spisok_org_members[corrent_id_to_rec].id)
                            register_check(last_orgname)
                            show_chat_notification("info", "Начата проверка", 
                                string.format("Начинаем проверку %d сотрудников", #spisok_org_members))
                        end
                    end
                else
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.5, 0.5, 0.5, 0.5))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.5, 0.5, 0.5, 0.5))
                    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.5, 0.5, 0.5, 0.5))
                    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.7, 0.7, 0.7, 0.7))
                    
                    if imgui.Button(ru("Начать проверку"), imgui.ImVec2(170, 45)) then
                    end
                    
                    imgui.PopStyleColor(4)
                    
                    if not time_allowed then
                        imgui.TextColored(ui_theme.warning, ru("Доступно с " .. config.check_time_start .. " до " .. config.check_time_end))
                    end
                    
                    if check_error_message ~= "" then
                        imgui.TextColored(ui_theme.error, ru(check_error_message))
                    end
                end
                
                imgui.SameLine()
                
                if imgui.Button(ru("Экспорт отчета"), imgui.ImVec2(170, 45)) then
                    local success, message = export_to_csv()
                    if success then
                        show_chat_notification("success", "Экспорт успешен", 
                            "Данные сохранены локально")
                    else
                        show_chat_notification("error", "Ошибка экспорта", message)
                    end
                end
                
                imgui.SameLine()
                
                if imgui.Button(ru("Заполнить форму"), imgui.ImVec2(170, 45)) then
                    if script_available then
                        calculate_auto_fields()
                        renderGovFormWindow[0] = true
                    else
                        show_chat_notification("error", "Доступ запрещен", "СКРИПТ ДОСТУПЕН С 3-ГО УРОВНЯ АДМИНКИ")
                    end
                end
                
                imgui.SameLine()
                
                if imgui.Button(ru("Копировать сводку"), imgui.ImVec2(170, 45)) then
                    local summary = string.format(
                        "Организация: %s\nВсего сотрудников: %d\nВ форме: %d (с выговорами: %d)\nАФК без ЕСК в форме: %d (с выговорами: %d)\nПрогульщиков в форме: %d (с выговорами: %d)",
                        last_orgname, #spisok_org_members, stats_inForm, stats_inFormVIG,
                        stats_afkBezEscInForm, stats_afkBezEscInFormVIG,
                        stats_walkedInFormInForm, stats_walkedInFormInFormVIG
                    )
                    setClipboardText(summary)
                    show_chat_notification("success", "Сводка скопирована", 
                        "Статистика скопирована в буфер обмена")
                end
                imgui.EndGroup()
                
                imgui.Spacing()
                imgui.Separator()
                
                imgui.BeginChild(ru("MembersList"), imgui.ImVec2(0, 400), true)
                
                imgui.Columns(5, ru("members_columns"), true)
                imgui.SetColumnWidth(0, 250)
                imgui.SetColumnWidth(1, 100)
                imgui.SetColumnWidth(2, 180)
                imgui.SetColumnWidth(3, 150)
                imgui.SetColumnWidth(4, 100)
                
                imgui.TextColored(ui_theme.accent, ru("Ник [ID]"))
                imgui.NextColumn()
                imgui.TextColored(ui_theme.accent, ru("Выговоры"))
                imgui.NextColumn()
                imgui.TextColored(ui_theme.accent, ru("Ранг"))
                imgui.NextColumn()
                imgui.TextColored(ui_theme.accent, ru("Статус"))
                imgui.NextColumn()
                imgui.TextColored(ui_theme.accent, ru("В форме"))
                imgui.NextColumn()
                
                imgui.Separator()
                
                for i, v in ipairs(spisok_org_members) do
                    local nick_color = tonumber(v.warns) > 0 and ui_theme.error or ui_theme.text
                    imgui.TextColored(nick_color, ru(string.format("%s [%s]", v.nick, v.id)))
                    if imgui.IsItemClicked() then
                        sampSendChat('/re ' .. v.id)
                    end
                    imgui.NextColumn()
                    
                    local warn_color = tonumber(v.warns) == 3 and ui_theme.error or 
                                      tonumber(v.warns) == 2 and ui_theme.warning or 
                                      tonumber(v.warns) == 1 and imgui.ImVec4(1, 1, 0, 1) or 
                                      ui_theme.success
                    imgui.TextColored(warn_color, ru(string.format("%d/3", tonumber(v.warns))))
                    imgui.NextColumn()
                    
                    imgui.Text(ru(v.rank))
                    imgui.NextColumn()
                    
                    local status_color = v.stats == 2 and ui_theme.success or
                                        v.stats == 3 and ui_theme.warning or
                                        v.stats == 5 and ui_theme.error or
                                        imgui.ImVec4(0.8, 0.8, 0.8, 1)
                    
                    imgui.TextColored(status_color, ru(status_members[v.stats]))
                    if imgui.IsItemClicked() then
                        v.stats = v.stats < #status_members and v.stats + 1 or 1
                    end
                    imgui.NextColumn()
                    
                    local form_color = v.working and ui_theme.success or ui_theme.error
                    imgui.TextColored(form_color, v.working and ru("Да") or ru("Нет"))
                    imgui.NextColumn()
                end
                
                imgui.Columns(1)
                imgui.EndChild()
                
            else
                if not script_available and my_lvl_adm > 0 then
                    imgui.TextColored(ui_theme.error, ru("СКРИПТ ДОСТУПЕН С 3-ГО УРОВНЯ АДМИНКИ"))
                else
                    imgui.Text(ru("Выберите организацию и нажмите 'Загрузить /members'..."))
                end
            end
            
        elseif page == 3 then
            imgui.TextColored(ui_theme.accent, ru("История отчетов"))
            imgui.Separator()
            
            if not script_available and my_lvl_adm > 0 then
                imgui.TextColored(ui_theme.error, ru("СКРИПТ ДОСТУПЕН С 3-ГО УРОВНЯ АДМИНКИ"))
            else
                if imgui.Button(ru("Обновить список"), imgui.ImVec2(150, 35)) then
                    local success, err = pcall(load_report_history)
                    if success then
                        show_chat_notification("info", "История обновлена", 
                            "Список отчетов обновлен")
                    else
                        show_chat_notification("error", "Ошибка загрузки", 
                            "Не удалось загрузить историю отчетов")
                    end
                end
                
                imgui.SameLine()
                
                if imgui.Button(ru("Открыть папку отчетов"), imgui.ImVec2(180, 35)) then
                    os.execute('mkdir "hosya_reports" 2>nul')
                    os.execute('start "" "hosya_reports"')
                    show_chat_notification("info", "Папка открыта", 
                        "Папка с отчетами открыта")
                end
                
                imgui.Spacing()
                
                if #report_history == 0 then
                    imgui.Text(ru("История отчетов пуста"))
                else
                    imgui.Text(ru(string.format("Всего отчетов: %d", #report_history)))
                    
                    imgui.BeginChild(ru("ReportsList"), imgui.ImVec2(0, 500), true)
                    
                    for i, report in ipairs(report_history) do
                        if i > 20 then break end
                        
                        local unique_id = "report_" .. i
                        
                        imgui.BeginGroup()
                        if imgui.Button(ru("Открыть") .. "##" .. unique_id, imgui.ImVec2(70, 35)) then
                            if doesFileExist(report.filename) then
                                os.execute('start "" "' .. report.filename .. '"')
                                show_chat_notification("info", "Отчет открыт", 
                                    "Файл отчета открыт")
                            else
                                show_chat_notification("error", "Файл не найден", 
                                    "Файл отчета не существует")
                            end
                        end
                        
                        imgui.SameLine()
                        
                        if imgui.Button(ru("Копировать") .. "##copy_" .. unique_id, imgui.ImVec2(90, 35)) then
                            setClipboardText(report.filename)
                            show_chat_notification("success", "Путь скопирован", 
                                "Путь к файлу скопирован")
                        end
                        
                        imgui.SameLine()
                        
                        imgui.Text(ru(string.format("[%s] %s (%d сотрудников)", 
                            report.date, report.org, report.total_members)))
                        
                        imgui.EndGroup()
                        
                        if i < #report_history and i < 20 then
                            imgui.Separator()
                        end
                    end
                    
                    imgui.EndChild()
                end
            end
            
        elseif page == 4 then
            imgui.TextColored(ui_theme.accent, ru("Информация о скрипте"))
            imgui.Separator()
            
            if not script_available and my_lvl_adm > 0 then
                imgui.TextColored(ui_theme.error, ru("СКРИПТ ДОСТУПЕН С 3-ГО УРОВНЯ АДМИНКИ"))
            else
                imgui.Text(ru("HOSYACheckActivity v" .. current_version))
                imgui.Spacing()
                
                local current_msk_time = get_current_time_display()
                imgui.TextColored(ui_theme.accent, ru(current_msk_time))
                
                imgui.Spacing()
                
                imgui.TextColored(ui_theme.accent, ru("Основные функции:"))
                imgui.BulletText(ru("Проверка активности сотрудников организаций"))
                imgui.BulletText(ru("Проверки разрешены только в указанное время (MSK)"))
                imgui.BulletText(ru("Форма активности для заполнения в игре"))
                imgui.BulletText(ru("Автоматическое сохранение отчетов в CSV"))
                imgui.BulletText(ru("Система автоматических обновлений"))
                
                imgui.Spacing()
                
                imgui.TextColored(ui_theme.accent, ru("Версия: ") .. current_version)
                if update_available then
                    imgui.TextColored(ui_theme.success, ru("Доступно обновление до v") .. latest_version)
                    if imgui.Button(ru("Установить обновление"), imgui.ImVec2(200, 35)) then
                        renderUpdateWindow[0] = true
                    end
                else
                    imgui.Text(ru("У вас последняя версия"))
                    if imgui.Button(ru("Проверить обновления"), imgui.ImVec2(200, 35)) then
                        check_for_updates()
                    end
                end
                
                imgui.Spacing()
                
                imgui.TextColored(ui_theme.accent, ru("Временные ограничения:"))
                local time_allowed, time_error = is_check_time_allowed()
                local time_status = time_allowed and "Разрешено" or "Запрещено"
                local time_status_color = time_allowed and ui_theme.success or ui_theme.warning
                
                imgui.TextColored(time_status_color, "• " .. ru("Проверка активности: " .. time_status))
                
                imgui.BulletText(ru("Разрешенное время: " .. config.check_time_start .. " - " .. config.check_time_end))
                
                local _, day_w = get_msk_time()
                local current_day = tonumber(day_w)
                if current_day == 0 then current_day = 7 end
                local day_name = day_names[current_day]
                imgui.BulletText(ru("Сегодня: " .. day_name .. " (" .. (config.check_days[current_day] and "разрешено" or "запрещено") .. ")"))
                
                imgui.Spacing()
                
                imgui.TextColored(ui_theme.accent, ru("Статистика проверок:"))
                local today_count, last_time = get_check_stats()
                if last_time ~= "" then
                    imgui.BulletText(ru("Последняя проверка: ") .. last_time)
                end
            end
            
            imgui.Spacing()
            
            if config.enable_check_reminders then
                local next_check_time = ru("сейчас")
                local current_time_str = os.date("%H:%M")
                local current_day = tonumber(os.date("%w"))
                if current_day == 0 then current_day = 7 end
                
                if config.check_days[current_day] then
                    if current_time_str < config.check_time_start then
                        next_check_time = ru("сегодня в ") .. config.check_time_start
                    elseif current_time_str > config.check_time_end then
                        for i = 1, 7 do
                            local next_day = (current_day + i - 1) % 7 + 1
                            if config.check_days[next_day] then
                                if i == 1 then
                                    next_check_time = ru("завтра в ") .. config.check_time_start
                                else
                                    next_check_time = day_names[next_day] .. " в " .. config.check_time_start
                                end
                                break
                            end
                        end
                    else
                        next_check_time = ru("сегодня до ") .. config.check_time_end
                    end
                else
                    for i = 1, 7 do
                        local next_day = (current_day + i - 1) % 7 + 1
                        if config.check_days[next_day] then
                            if i == 1 then
                                next_check_time = ru("завтра в ") .. config.check_time_start
                            else
                                next_check_time = day_names[next_day] .. " в " .. config.check_time_start
                            end
                            break
                        end
                    end
                end
            end
        end
        
        imgui.EndChild()
        imgui.End()
    end
)

-- ================== ОКНО ПРОВЕРКИ СОТРУДНИКОВ ==================
local checkMembersFrame = imgui.OnFrame(
    function() return renderMembersWindow[0] end,
    function()
        update_animations()
        
        local theme = themes[config.theme] or themes.dark_blue
        local ui_theme = theme.ui
        
        imgui.SetNextWindowBgAlpha(animation_values.check_window_alpha)
        
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX - 550, sizeY / 3), imgui.Cond.FirstUseEver, imgui.ImVec2(0.0, 0.0))
        imgui.SetNextWindowSize(imgui.ImVec2(500, 300))
        
        imgui.Begin(ru("Проверка сотрудников"), renderMembersWindow, 
            imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
        
        if #spisok_org_members > 0 and corrent_id_to_rec <= #spisok_org_members then
            local current = spisok_org_members[corrent_id_to_rec]
            local online_count = #spisok_org_members - 1
            local working_count = 0
            local afk_without_esc_count = 0
            local walked_count = 0
            local other_count = 0
            
            for _, member in ipairs(spisok_org_members) do
                if member.working then
                    if member.stats == 2 then 
                        working_count = working_count + 1
                    elseif member.stats == 3 then 
                        afk_without_esc_count = afk_without_esc_count + 1
                    elseif member.stats == 5 then 
                        walked_count = walked_count + 1
                    elseif member.stats == 1 or member.stats == 4 then 
                        other_count = other_count + 1
                    end
                end
            end

            local working_percentage = online_count > 0 and math.floor((working_count / online_count) * 100) or 0
            local walked_percentage = online_count > 0 and math.floor((walked_count / online_count) * 100) or 0
            local afk_percentage = online_count > 0 and math.floor((afk_without_esc_count / online_count) * 100) or 0
            local other_percentage = online_count > 0 and math.floor((other_count / online_count) * 100) or 0
            
            imgui.ProgressBar(corrent_id_to_rec / #spisok_org_members, imgui.ImVec2(-1, 15))
            imgui.Text(ru(string.format("Прогресс: %d/%d (%.1f%%)", 
                corrent_id_to_rec, #spisok_org_members, 
                (corrent_id_to_rec / #spisok_org_members) * 100)))
            
            imgui.TextColored(ui_theme.accent, ru(string.format("Текущий сотрудник: %s [%s]", 
                current.nick, current.id)))
            
            imgui.Text(ru(string.format("Ранг: %s | Выговоры: %d/3", 
                current.rank, tonumber(current.warns))))
            
            imgui.Separator()
            imgui.Spacing()
            
            imgui.Text(ru("Выберите статус:"))
            imgui.Spacing()
            
            local button_size = imgui.ImVec2(105, 30)
            
            imgui.BeginGroup()
            
            local button_color = ui_theme.success
            imgui.PushStyleColor(imgui.Col.Button, button_color)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(
                math.min(button_color.x + 0.1, 1.0),
                math.min(button_color.y + 0.1, 1.0),
                math.min(button_color.z + 0.1, 1.0),
                1.0
            ))
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 1, 1, 1))
            
            if imgui.Button(ru("Работает[2]"), button_size) then
                current.stats = 2
                next_employee()
            end
            
            imgui.PopStyleColor(3)
            
            imgui.SameLine()
            
            button_color = ui_theme.warning
            imgui.PushStyleColor(imgui.Col.Button, button_color)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(
                math.min(button_color.x + 0.1, 1.0),
                math.min(button_color.y + 0.1, 1.0),
                math.min(button_color.z + 0.1, 1.0),
                1.0
            ))
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 1, 1, 1))
            
            if imgui.Button(ru("АФК без ЕСК[3]"), button_size) then
                current.stats = 3
                next_employee()
            end
            
            imgui.PopStyleColor(3)
            
            imgui.SameLine()
            
            button_color = imgui.ImVec4(1, 1, 0.3, 1)
            imgui.PushStyleColor(imgui.Col.Button, button_color)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(
                math.min(button_color.x + 0.1, 1.0),
                math.min(button_color.y + 0.1, 1.0),
                math.min(button_color.z + 0.1, 1.0),
                1.0
            ))
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0, 0, 0, 1))
            
            if imgui.Button(ru("АФК[4]"), button_size) then
                current.stats = 4
                next_employee()
            end
            
            imgui.PopStyleColor(3)
            
            imgui.SameLine()
            
            button_color = ui_theme.error
            imgui.PushStyleColor(imgui.Col.Button, button_color)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(
                math.min(button_color.x + 0.1, 1.0),
                math.min(button_color.y + 0.1, 1.0),
                math.min(button_color.z + 0.1, 1.0),
                1.0
            ))
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 1, 1, 1))
            
            if imgui.Button(ru("Личные дела[5]"), button_size) then
                current.stats = 5
                next_employee()
            end
            
            imgui.PopStyleColor(3)
            
            imgui.EndGroup()
            
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            if imgui.Button(ru("Завершить проверку"), imgui.ImVec2(-1, 35)) then
                renderMembersWindow[0] = false
                renderWindow[0] = true
                check_status_members = false
                last_time_stop_check_members = os.date('%H:%M:%S')

                show_final_report()
                
                show_chat_notification("warning", "Проверка прервана", 
                    "Проверка организации прервана пользователем")
            end
            if renderMembersWindow[0] then
                if wasKeyPressed(vkeys.VK_2) and not imgui.GetIO().WantCaptureKeyboard then
                    if corrent_id_to_rec <= #spisok_org_members then
                        spisok_org_members[corrent_id_to_rec].stats = 2
                        next_employee()
                    end
                elseif wasKeyPressed(vkeys.VK_3) and not imgui.GetIO().WantCaptureKeyboard then
                    if corrent_id_to_rec <= #spisok_org_members then
                        spisok_org_members[corrent_id_to_rec].stats = 3
                        next_employee()
                    end
                elseif wasKeyPressed(vkeys.VK_4) and not imgui.GetIO().WantCaptureKeyboard then
                    if corrent_id_to_rec <= #spisok_org_members then
                        spisok_org_members[corrent_id_to_rec].stats = 4
                        next_employee()
                    end
                elseif wasKeyPressed(vkeys.VK_5) and not imgui.GetIO().WantCaptureKeyboard then
                    if corrent_id_to_rec <= #spisok_org_members then
                        spisok_org_members[corrent_id_to_rec].stats = 5
                        next_employee()
                    end
                end
            else
            end
            
        else
            imgui.Text(ru("Нет данных для проверки"))
            if imgui.Button(ru("Закрыть"), imgui.ImVec2(-1, 45)) then
                renderMembersWindow[0] = false
                renderWindow[0] = true
            end
        end
        
        imgui.End()
    end
)

-- ================== ОКНО ФОРМА ОТЧЕТНОСТИ ==================
local govFormFrame = imgui.OnFrame(
    function() return renderGovFormWindow[0] end,
    function()
        update_animations()
        
        local theme = themes[config.theme] or themes.dark_blue
        local ui_theme = theme.ui
        
        imgui.SetNextWindowBgAlpha(animation_values.gov_form_alpha)
        
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(700, 750))
        
        imgui.Begin(ru("Форма отчетности организаций"), renderGovFormWindow, imgui.WindowFlags.NoCollapse)
        
        -- Проверка доступности
        if my_lvl_adm < 3 and my_lvl_adm > 0 then
            imgui.TextColored(ui_theme.error, ru("СКРИПТ ДОСТУПЕН С 3-ГО УРОВНЯ АДМИНКИ"))
            if imgui.Button(ru("Закрыть"), imgui.ImVec2(-1, 45)) then
                renderGovFormWindow[0] = false
            end
            imgui.End()
            return
        end
        
        imgui.TextColored(ui_theme.accent, ru("Заполните поле собеседования, остальное заполнится автоматически, после проверки организации"))
        imgui.Separator()
        
        imgui.BeginChild(ru("FormContent"), imgui.ImVec2(0, 600), true)
        
        imgui.Text(ru("1. Лидер/зам в сети:"))
        imgui.SameLine()
        imgui.Checkbox(ru("##leader_online"), gov_form.leader_online)
        
        imgui.Spacing()
        
        imgui.Text(ru("2. Количество сотрудников ВСЕГО (/members):"))
        imgui.SameLine()
        imgui.InputText(ru("##members_count"), gov_form.members_count, 10)
        
        imgui.Spacing()
        
        imgui.Text(ru("4. Количество сотрудников в форме и занимающихся работой:"))
        imgui.SameLine()
        imgui.InputText(ru("##working_in_form"), gov_form.working_in_form, 10)
        
        imgui.Spacing()
        
        imgui.Text(ru("5. Количество прогульщиков/афкашников БЕЗ еска:"))
        imgui.SameLine()
        imgui.InputText(ru("##afk_without_esc"), gov_form.afk_without_esc, 10)
        
        imgui.Spacing()
        
        imgui.Text(ru("6. Количество прогульщиков/АФКашников без ЕСКа имеющих выговор (-ы):"))
        imgui.SameLine()
        imgui.InputText(ru("##afk_with_warnings"), gov_form.afk_with_warnings, 10)
        
        imgui.Spacing()
        
        local point_9_text = org_9th_point[last_orgname] or "Состав выполняет свои обязанности"
        imgui.Text(ru("8. " .. point_9_text .. ":"))
        imgui.SameLine()
        imgui.Checkbox(ru("##lobby_employee"), gov_form.lobby_employee)
        
        imgui.Spacing()

        imgui.Text(ru("9. За последние 24 часа было проведено как минимум 1 собеседование:"))
        imgui.SameLine()
        imgui.Checkbox(ru("##interviews_24h"), gov_form.interviews_24h)
        
        imgui.Spacing()
        
        imgui.Text(ru("10. Оценка работы состава (автоматически):"))
        imgui.SameLine()
        imgui.InputText(ru("##work_with_staff"), gov_form.work_with_staff, 32)
        
        imgui.Spacing()
        
        imgui.Text(ru("11. Оценка работы с прогульщиками (автоматически):"))
        imgui.SameLine()
        imgui.InputText(ru("##work_with_absentees"), gov_form.work_with_absentees, 32)
        
        imgui.EndChild()
        
        imgui.Separator()

        if imgui.Button(ru("Заполнить форму заново (авто)"), imgui.ImVec2(200, 45)) then
            calculate_auto_fields()
        end
        
        imgui.SameLine()
        
        if imgui.Button(ru("Скопировать BB-код"), imgui.ImVec2(180, 45)) then
            local form_text = generate_gov_form_text()
            setClipboardText(form_text)
            show_chat_notification("success", "Форма сгенерирована", 
                "Текст формы скопирован в буфер обмена")
        end
        
        imgui.SameLine()
        
        if imgui.Button(ru("Очистить форму"), imgui.ImVec2(130, 45)) then
            gov_form.interviews_24h[0] = false
            ffi.copy(gov_form.members_count, "0")
            ffi.copy(gov_form.working_in_form, "0")
            ffi.copy(gov_form.afk_without_esc, "0")
            ffi.copy(gov_form.afk_with_warnings, "0")
            gov_form.lobby_employee[0] = false
            gov_form.leader_online[0] = false
            ffi.copy(gov_form.work_with_staff, "")
            ffi.copy(gov_form.work_with_absentees, "")
            gov_form.min_active[0] = false
            gov_form.members_norm[0] = false
            
            show_chat_notification("info", "Форма очищена", "Все поля формы сброшены")
        end
        
        imgui.SameLine()
        
        if imgui.Button(ru("Закрыть"), imgui.ImVec2(80, 45)) then
            renderGovFormWindow[0] = false
        end
        
        imgui.End()
    end
)

-- ================== ОКНО НАСТРОЙКИ ==================
local settingsFrame = imgui.OnFrame(
    function() return renderSettingsWindow[0] end,
    function()
        update_animations()
        
        local theme = themes[config.theme] or themes.dark_blue
        local ui_theme = theme.ui
        
        imgui.SetNextWindowBgAlpha(animation_values.settings_window_alpha)
        
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(600, 700))
        
        imgui.Begin(ru("Настройки"), renderSettingsWindow, imgui.WindowFlags.NoResize)
        
        -- Проверка доступности
        if my_lvl_adm < 3 and my_lvl_adm > 0 then
            imgui.TextColored(ui_theme.error, ru("СКРИПТ ДОСТУПЕН С 3-ГО УРОВНЯ АДМИНКИ"))
            if imgui.Button(ru("Закрыть"), imgui.ImVec2(-1, 45)) then
                renderSettingsWindow[0] = false
            end
            imgui.End()
            return
        end
        
        imgui.TextColored(ui_theme.accent, ru("Внешний вид"))
        imgui.Separator()
        
        local theme_index = 1
        for theme_name, theme_data in pairs(themes) do
            if imgui.Button(ru(theme_data.name), imgui.ImVec2(180, 35)) then
                config.theme = theme_name
                save_config()
                show_chat_notification("success", "Тема изменена", 
                    "Тема оформления обновлена")
            end
            if theme_index < 3 then
                imgui.SameLine()
            end
            theme_index = theme_index + 1
        end
        
        imgui.Spacing()
        imgui.Separator()
        
        imgui.TextColored(ui_theme.accent, ru("Уведомления"))
        imgui.Separator()
        
        if imgui.Checkbox(ru("Показывать уведомления"), show_notifications_bool) then
            config.show_notifications = show_notifications_bool[0]
            save_config()
        end
        
        imgui.Spacing()
        
        if imgui.Checkbox(ru("Автосохранение отчетов"), auto_save_reports_bool) then
            config.auto_save_reports = auto_save_reports_bool[0]
            save_config()
        end
        
        imgui.Spacing()
        if imgui.Checkbox(ru("Включить напоминания о проверках"), enable_check_reminders_bool) then
            config.enable_check_reminders = enable_check_reminders_bool[0]
            save_config()
        end
        
        imgui.Spacing()
        
        if imgui.Checkbox(ru("Автопроверка обновлений при запуске"), auto_check_updates_bool) then
            config.auto_check_updates = auto_check_updates_bool[0]
            save_config()
        end
        
        imgui.Spacing()
        
        imgui.Separator()
        
        imgui.TextColored(ui_theme.accent, ru("Настройки напоминаний"))
        imgui.Separator()
        
        
        imgui.Text(ru("Организация для проверки:"))
        imgui.SameLine()
        if imgui.InputText(ru("##check_org"), check_org_input, 256) then
            config.check_organization = ffi.string(check_org_input)
        end
        
        imgui.Spacing()
        
        imgui.Text(ru("Время проверки (в вашем часовом поясе):"))
        imgui.SameLine(0, 10)
        imgui.Text(ru("С:"))
        imgui.SetNextItemWidth(60)
        imgui.SameLine()
        if imgui.InputText(ru("##time_start"), check_time_start_input, 6) then
            config.check_time_start = ffi.string(check_time_start_input)
        end
        
        imgui.SameLine(0, 10)
        imgui.Text(ru("До:"))
        imgui.SetNextItemWidth(60)
        imgui.SameLine()
        if imgui.InputText(ru("##time_end"), check_time_end_input, 6) then
            config.check_time_end = ffi.string(check_time_end_input)
        end
        
        imgui.Spacing()
        
        imgui.Text(ru("Дни проверки:"))
        for i = 1, 7 do
            imgui.SameLine()
            if imgui.Checkbox(ru(day_names[i]:sub(1, 2)), check_days_bools[i]) then
                config.check_days[i] = check_days_bools[i][0]
                save_config()
            end
        end
        
        imgui.Spacing()
        imgui.Separator()
        
        if imgui.Button(ru("Сохранить все настройки"), imgui.ImVec2(180, 40)) then
            save_config()
            show_chat_notification("success", "Настройки сохранены", 
                "Все настройки успешно сохранены")
        end
        
        imgui.SameLine()
        
        if imgui.Button(ru("Закрыть"), imgui.ImVec2(80, 40)) then
            renderSettingsWindow[0] = false
        end
        
        imgui.End()
    end
)

function ev.onServerMessage(color, text)
    if text:find("Игрок не найден") and check_status_members then
        if corrent_id_to_rec < #spisok_org_members then
            corrent_id_to_rec = corrent_id_to_rec + 1
            sampSendChat('/re ' .. spisok_org_members[corrent_id_to_rec].id)
        else
            renderMembersWindow[0] = false
            renderWindow[0] = true
            check_status_members = false
            last_time_stop_check_members = os.date('%H:%M:%S')
        end
        return false
    end
    return true
end

function ev.onShowDialog(dialogId, style, title, button1, button2, text)
    if check_my_lvl_adm then
        if dialogId == 27090 or dialogId == 8310 or dialogId == 8311 or dialogId == 8312 then
            if dialogId == 27090 and button2 == "Закрыть" then
                pcall(function()
                    sampSendDialogResponse(dialogId, 1, 0, "[1] Admins")
                end)
                return false
            end
            
            if dialogId == 8310 then
                local result, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
                if result then
                    local mynick = sampGetPlayerNickname(id)
                    
                    if text:find(mynick, 1, true) then
                        for line in text:gmatch("[^\r\n]+") do
                            if line:find(mynick, 1, true) then
                                local lvl_str = line:match("%[(%d+)%s+lvl%]")
                                if lvl_str then
                                    my_lvl_adm = tonumber(lvl_str)
                                    admin_level_text = "Уровень " .. my_lvl_adm
                                end
                            end
                        end
                        check_my_lvl_adm = false
                        lua_thread.create(function()
                            wait(100)
                            pcall(function()
                                sampSendDialogResponse(dialogId, 0, 1, "")
                            end)
                            wait(100)
                            pcall(function()
                                sampSendDialogResponse(27090, 0, 1, "")
                            end)
                        end)
                        return false
                    end
                end
                
                if text:find("Следующая") then
                    pcall(function()
                        sampSendDialogResponse(dialogId, 1, 15, ">>> Следующая страница")
                    end)
                    return false
                else
                    check_my_lvl_adm = false
                    show_chat_notification("warning", "Админка не определена", 
                        "Не удалось найти себя в списке админов")
                    lua_thread.create(function()
                        wait(100)
                        pcall(function()
                            sampSendDialogResponse(dialogId, 0, 1, "")
                        end)
                        wait(100)
                        pcall(function()
                            sampSendDialogResponse(27090, 0, 1, "")
                        end)
                    end)
                    return false
                end
            end
            
            if check_my_lvl_adm then
                pcall(function()
                    sampSendDialogResponse(dialogId, 0, 1, "")
                end)
                return false
            end
        end
    end
     if dialogId == 27882 or dialogId == 2015 then
        last_orgname = title:match("{FFFFFF}([^%(|]+)%(") or "Неизвестно"
        if not check_members and not loading_members then
                return true
        end
        if not check_members then
            loading_members = false
            lua_thread.create(function()
                wait(100)
                pcall(function()
                    sampSendDialogResponse(dialogId, 0, 1, "")
                end)
            end)
            return false
        end
        
        for line in text:gmatch('[^\r\n]+') do
            if not line:find('Ник') and not line:find('страница') then
                line = line:gsub("{FFA500}%(Вы%)", "")
                line = line:gsub(" / в деморгане", "")
                
                if line:find('{FFA500}%(%d+.+%)') then
                    local color, nickname, id, rank, rank_number, color2, rank_time, warns, afk = string.match(line, "{(%x%x%x%x%x%x)}([%w_]+)%((%d+)%)%s*([^%(]+)%((%d+)%)%s*{(%x%x%x%x%x%x)}%(([^%)]+)%)%s*{FFFFFF}(%d+)%s*%[%d+%]%s*/%s*(%d+)%s*%d+ шт")
                    if color and nickname and id and rank and rank_number and warns and afk then
                        local working = color:find('90EE90') and true or false
                        if rank_time then
                            rank_number = rank_number .. ') (' .. rank_time
                        end
                        table.insert(spisok_org_members, { 
                            nick = nickname, 
                            id = id, 
                            rank = rank, 
                            rank_number = tonumber(rank_number),
                            warns = warns, 
                            afk = afk, 
                            working = working, 
                            stats = 1
                        })
                    end
                else
                    local color, nickname, id, rank, rank_number, rank_time, warns, afk = string.match(line, "{(%x%x%x%x%x%x)}%s*([^%(]+)%((%d+)%)%s*([^%(]+)%((%d+)%)%s*([^{}]+){FFFFFF}%s*(%d+)%s*%[%d+%]%s*/%s*(%d+)%s*%d+ шт")
                    if color and nickname and id and rank and rank_number and warns and afk then
                        local working = color:find('90EE90') and true or false
                        table.insert(spisok_org_members, { 
                            nick = nickname, 
                            id = id, 
                            rank = rank, 
                            rank_number = tonumber(rank_number),
                            warns = warns, 
                            afk = afk, 
                            working = working, 
                            stats = 1
                        })
                    end
                end
            end
        end
        
        if text:find("Следующая") then
            if text:find("Предыдущая") then
                sampSendDialogResponse(dialogId, 1, 16, "[>>>] Следующая страница")
            else
                sampSendDialogResponse(dialogId, 1, 15, "[>>>] Следующая страница")
            end
            return false
        else
            check_members = false
            loading_members = false
            local leader_count = 0
            for _, member in ipairs(spisok_org_members) do
                if member.rank_number and (tonumber(member.rank_number) == 9 or tonumber(member.rank_number) == 10) then
                    leader_count = leader_count + 1
                end
            end
            
            show_chat_notification("success", "Данные загружены", 
                string.format("Загружено %d сотрудников организации: %s (лидеров/замов: %d)", 
                    #spisok_org_members, last_orgname, leader_count))
            sampSendDialogResponse(dialogId, 0, 1, "")
            return false
        end
    end
    
    return true
end

-- ================== ОСНОВНАЯ ФУНКЦИЯ ==================
local function safe_main()
    local success, err = pcall(function()
        load_config()

        load_check_history()

        local success, err = pcall(load_report_history)
        if not success then
            report_history = {}
            printStringNow("HOSYACheckActivity: Не удалось загрузить историю отчетов", 1000)
        end
        
        os.execute('mkdir "hosya_reports" 2>nul')
        os.execute('mkdir "' .. UPDATE_FOLDER .. '" 2>nul')
        os.execute('mkdir "' .. BACKUP_FOLDER .. '" 2>nul')
        
        ffi.copy(check_time_start_input, config.check_time_start)
        ffi.copy(check_time_end_input, config.check_time_end)
        ffi.copy(check_org_input, config.check_organization)
        
        auto_save_reports_bool[0] = config.auto_save_reports
        show_notifications_bool[0] = config.show_notifications
        enable_check_reminders_bool[0] = config.enable_check_reminders
        max_checks_input[0] = config.max_checks_per_day
        auto_check_updates_bool[0] = config.auto_check_updates
        
        for i = 1, 7 do
            check_days_bools[i][0] = config.check_days[i]
        end
        
        -- АВТОПРОВЕРКА ОБНОВЛЕНИЙ ПРИ ЗАПУСКЕ
        if config.auto_check_updates then
            auto_check_updates()
        end
        
        sampRegisterChatCommand("hosya", function()
            renderWindow[0] = not renderWindow[0]
            if my_lvl_adm == 0 then
                check_admin_level_on_start()
            end
            
            lua_thread.create(function()
                wait(100)
                local success = pcall(function()
                    sampSendChat("/members")
                end)
                
                loading_members = true
                loading_progress = "Определение организации"
                loading_dots = ""
                loading_last_update = os.clock()
            end)
        end)
        
        sampRegisterChatCommand("govform", function()
            renderGovFormWindow[0] = true
        end)
        
        sampRegisterChatCommand("hosya_stats", function()
            local today_count, last_time = get_check_stats()
            show_chat_notification("info", "Статистика проверок", 
                string.format("Последняя проверка: %s", 
                    last_time ~= "" and last_time or "не было"))
        end)
        
        -- Добавляем команду для открытия окна обновлений
        sampRegisterChatCommand("update", function()
            renderUpdateWindow[0] = true
            check_for_updates()
        end)
        
        safe_chat(ru("{32CD32}[HOSYACheckActivity] {FFFFFF}Успешно загружен! Используйте /hosya"))
        show_chat_notification("info", "Загрузка", "HOSYACheckActivity v" .. current_version .. " загружен.")
        
        local last_reminder_check = 0
        local last_reminder_time = 0

        while true do
            wait(0)

            if loading_members then
                local current_time = os.clock()
                if current_time - loading_last_update > 0.5 then
                    loading_last_update = current_time
                    loading_dots = loading_dots == "..." and "" or loading_dots .. "."
                end
            end
            
            local current_time = os.time()
            if current_time - last_reminder_check > 60 then
                if config.enable_check_reminders then
                    local current_time_msk, current_day_w = get_msk_time()
                    local current_day = tonumber(current_day_w)
                    if current_day == 0 then current_day = 7 end
                    
                    if config.check_days[current_day] then
                        if current_time_msk >= config.check_time_start and current_time_msk <= config.check_time_end then
                            local reminder_interval_seconds = config.reminder_interval_minutes * 60
                            if not last_reminder_time or os.time() - last_reminder_time > reminder_interval_seconds then
                                show_chat_notification("warning", "Напоминание о проверке",
                                    string.format("Время проверки активности организации: %s (до %s MSK)", 
                                        config.check_organization, config.check_time_end))
                                last_reminder_time = os.time()
                            end
                        end
                    end
                end
                last_reminder_check = current_time
            end
            
            if isKeyJustPressed(vkeys.VK_ESCAPE) then
                if renderMembersWindow[0] then
                    renderMembersWindow[0] = false
                    renderWindow[0] = true
                elseif renderSettingsWindow[0] then
                    renderSettingsWindow[0] = false
                elseif renderGovFormWindow[0] then
                    renderGovFormWindow[0] = false
                elseif renderUpdateWindow[0] then
                    renderUpdateWindow[0] = false
                end
            end
            
            -- Горячая клавиша для обновлений (Ctrl+U)
            if isKeyDown(vkeys.VK_CONTROL) and isKeyJustPressed(vkeys.VK_U) then
                renderUpdateWindow[0] = not renderUpdateWindow[0]
                if renderUpdateWindow[0] then
                    check_for_updates()
                end
            end
        end
    end)
    
    if not success then
        printStringNow(ru("HOSYACheckActivity: Ошибка запуска: ") .. tostring(err), 1000)
        safe_chat(ru("{FF0000}[HOSYACheckActivity] {FFFFFF}Ошибка запуска: ") .. tostring(err))
    end
end

safe_main()
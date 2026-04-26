/*
================================================================================
                          bank_system.pwn — Filterscript
                       Банк, кредиты и займы для SA-MP
                          Автор: aiopus / Devin (2026)
================================================================================

ОПИСАНИЕ
--------
Полноценный filterscript для RP-серверов SA-MP, реализующий:
  * Банковские счета игроков (баланс, пополнение, снятие, переводы, история)
  * Систему кредитов (большая сумма, низкий процент, долгий срок)
  * Систему быстрых займов (малая сумма, высокий процент, короткий срок)
  * Хранение всех данных в SQLite (через стандартный API SA-MP)
  * Пикапы и 3D-метки у банка, банкомата и кредитного отдела
  * Диалоговые окна для всех операций
  * Защиту от типичных видов абуза (отрицательные суммы, перевод самому
    себе, спам диалогами и т. д.)
  * Админское меню банка (просмотр, выдача, закрытие кредита/займа,
    очистка истории)

УСТАНОВКА
---------
1. Скопируйте этот файл в каталог `filterscripts/` вашего сервера SA-MP
   (рядом с pawno/include должен быть `a_samp.inc`).
2. Скомпилируйте его компилятором pawncc:
        pawncc filterscripts/bank_system.pwn -d2 -;+ -(+ -\)+
   В результате появится `bank_system.amx` — скопируйте его в
   `filterscripts/`.
3. В `server.cfg` добавьте filterscript в строку `filterscripts`:
        filterscripts bank_system
   (либо допишите `bank_system` через пробел к уже существующим).
4. Запустите сервер. При первом запуске автоматически создастся файл
   базы данных `scriptfiles/bank_system.db` и две таблицы:
     * `bank_accounts` — счета игроков
     * `bank_history`  — история операций
5. Проверка работоспособности:
     * Зайдите на сервер и наберите `/bank` — откроется главное меню.
     * Подойдите к банку (координаты см. в #define BANK_*) — должен
       сработать пикап.

ЗАВИСИМОСТИ
-----------
Используются ТОЛЬКО стандартные include `a_samp` (входит в SA-MP сервер
пакет). Никаких sscanf / zcmd / y_ini / mysql не требуется. Команды
обрабатываются вручную в `OnPlayerCommandText`, парсинг аргументов —
через `strval`/`strcmp`. Это сделано намеренно, чтобы filterscript
работал «из коробки».

ФАЙЛЫ, КОТОРЫЕ ПОЯВЯТСЯ ПОСЛЕ ЗАПУСКА
-------------------------------------
  scriptfiles/bank_system.db — SQLite БД (счета и история)

ИЗМЕНЕНИЕ НАСТРОЕК
------------------
В разделе «КОНФИГУРАЦИЯ» (см. ниже) собраны все ключевые параметры:
комиссии, проценты, сроки, штрафы, координаты пикапов и cooldown'ы
команд. Меняйте их под себя — перекомпилировать достаточно один раз.

================================================================================
*/

#include <a_samp>

/* ============================================================================
 *                              КОНФИГУРАЦИЯ
 * Все ключевые параметры filterscript-а собраны здесь. Меняйте под себя.
 * ==========================================================================*/

// ----- Файл базы данных (располагается в каталоге scriptfiles/) -------------
#define BANK_DB_FILE                "bank_system.db"

// ----- Лимиты операций ------------------------------------------------------
#define BANK_MIN_OPERATION          1           // минимальная сумма любой операции
#define BANK_MAX_OPERATION          100000000   // максимальная сумма за одну операцию
#define BANK_TRANSFER_FEE_PERCENT   2           // комиссия за перевод (в процентах)

// ----- Настройки кредитов ---------------------------------------------------
#define BANK_CREDIT_MAX             1000000     // максимальная сумма кредита
#define BANK_CREDIT_MIN             5000        // минимальная сумма кредита
#define BANK_CREDIT_PERCENT         15          // процент по кредиту (на всю сумму)
#define BANK_CREDIT_DAYS            30          // срок кредита (в днях)
#define BANK_CREDIT_PENALTY         5000        // штраф за просрочку платежа
#define BANK_CREDIT_DAY_SECONDS     86400       // 1 день в секундах (для теста уменьшайте)

// ----- Настройки займов -----------------------------------------------------
#define BANK_LOAN_MAX               50000       // максимальная сумма займа
#define BANK_LOAN_MIN               500         // минимальная сумма займа
#define BANK_LOAN_PERCENT           25          // процент по займу
#define BANK_LOAN_DAYS              3           // срок займа (в днях)
#define BANK_LOAN_PENALTY           2000        // штраф за просрочку
#define BANK_LOAN_DAY_SECONDS       86400       // 1 день в секундах

// ----- Anti-spam ------------------------------------------------------------
#define BANK_CMD_COOLDOWN_MS        1500        // кулдаун между командами (мс)

// ----- История --------------------------------------------------------------
#define BANK_HISTORY_LIMIT          25          // показывать N последних операций

// ----- Координаты пикапов ---------------------------------------------------
// Банк (Los Santos, City Hall area)
#define BANK_PICKUP_X               1462.4584
#define BANK_PICKUP_Y               -1011.0142
#define BANK_PICKUP_Z               26.8438
#define BANK_PICKUP_MODEL           1274        // зелёный значок $

// Банкомат (рядом с торговым центром)
#define ATM_PICKUP_X                1481.3580
#define ATM_PICKUP_Y                -1772.4143
#define ATM_PICKUP_Z                18.7958
#define ATM_PICKUP_MODEL            1274

// Кредитный отдел (другая точка LS)
#define CREDIT_PICKUP_X             1481.0613
#define CREDIT_PICKUP_Y             -1768.7357
#define CREDIT_PICKUP_Z             18.7958
#define CREDIT_PICKUP_MODEL         1239        // ! значок

// ----- Цвета сообщений ------------------------------------------------------
#define COLOR_BANK_INFO             0x33AA33FF
#define COLOR_BANK_ERROR            0xCC2222FF
#define COLOR_BANK_USAGE            0xFFFF00FF
#define COLOR_BANK_LABEL            0x33CCFFFF

/* ============================================================================
 *                        ИДЕНТИФИКАТОРЫ ДИАЛОГОВ
 * Сделаны от 7300, чтобы не конфликтовать с другими скриптами.
 * ==========================================================================*/
enum
{
    DIALOG_BANK_MAIN = 7300,
    DIALOG_BANK_BALANCE,
    DIALOG_BANK_DEPOSIT,
    DIALOG_BANK_WITHDRAW,
    DIALOG_BANK_TRANSFER_ID,
    DIALOG_BANK_TRANSFER_SUM,
    DIALOG_BANK_HISTORY,

    DIALOG_CREDIT_MAIN,
    DIALOG_CREDIT_TAKE,
    DIALOG_CREDIT_PAY,
    DIALOG_CREDIT_INFO,

    DIALOG_LOAN_MAIN,
    DIALOG_LOAN_TAKE,
    DIALOG_LOAN_PAY,
    DIALOG_LOAN_INFO,

    DIALOG_ADMIN_MAIN,
    DIALOG_ADMIN_TARGET_ID,
    DIALOG_ADMIN_ACTION,
    DIALOG_ADMIN_INPUT
};

/* ============================================================================
 *                       ТИПЫ ОПЕРАЦИЙ ИСТОРИИ
 * ==========================================================================*/
#define HIST_DEPOSIT        1
#define HIST_WITHDRAW       2
#define HIST_TRANSFER_OUT   3
#define HIST_TRANSFER_IN    4
#define HIST_CREDIT_TAKEN   5
#define HIST_CREDIT_PAID    6
#define HIST_LOAN_TAKEN     7
#define HIST_LOAN_PAID      8
#define HIST_PENALTY        9
#define HIST_ADMIN          10

/* ============================================================================
 *                     АДМИНСКИЕ ДЕЙСТВИЯ (для меню)
 * ==========================================================================*/
#define ADM_ACT_VIEW            0
#define ADM_ACT_GIVE_MONEY      1
#define ADM_ACT_TAKE_MONEY      2
#define ADM_ACT_GIVE_CREDIT     3
#define ADM_ACT_CLOSE_CREDIT    4
#define ADM_ACT_CLOSE_LOAN      5
#define ADM_ACT_CLEAR_HISTORY   6

/* ============================================================================
 *                       ПЕРЕМЕННЫЕ И СТРУКТУРЫ
 * ==========================================================================*/

// Дескриптор базы данных (DB:0 = ошибка/нет соединения)
new DB:gBankDB = DB:0;

// Пикапы и 3D-тексты (создаются в OnFilterScriptInit)
new gBankPickup,    Text3D:gBankLabel;
new gAtmPickup,     Text3D:gAtmLabel;
new gCreditPickup,  Text3D:gCreditLabel;

// Таймер для проверки просрочек кредитов и займов
new gPaymentTimer;

// Данные игрока в памяти
enum E_BANK_PLAYER
{
    bLoaded,                // 1 если данные подгружены из БД
    bAccountID,             // ID строки в bank_accounts (0 если новый)
    bBalance,               // деньги на банковском счёте
    bCreditAmount,          // изначально взятая сумма кредита
    bCreditDebt,            // оставшийся долг
    bCreditDaily,           // ежедневный платёж
    bCreditTaken,           // unix-таймстамп взятия
    bCreditNextPay,         // unix-таймстамп ближайшего платежа
    bLoanAmount,
    bLoanDebt,
    bLoanTaken,
    bLoanDue,               // дедлайн возврата
    bLastCmdTick,           // GetTickCount() последнего использования команды
    // временные поля для многошаговых диалогов
    bTransferTarget,        // playerid цели перевода
    bAdminTarget,           // playerid цели админ-действия
    bAdminAction            // выбранное админ-действие
};
new gPlayer[MAX_PLAYERS][E_BANK_PLAYER];

/* ============================================================================
 *                          FORWARD-ДЕКЛАРАЦИИ
 * ==========================================================================*/
forward Bank_OnPaymentTimer();

/* ============================================================================
 *                              ХЕЛПЕРЫ
 * ==========================================================================*/

// Безопасное получение имени игрока (24 символа + \0)
stock Bank_GetName(playerid, dest[], len)
{
    if(IsPlayerConnected(playerid))
        GetPlayerName(playerid, dest, len);
    else
        dest[0] = '\0';
}

// Экранирование апострофов для безопасной подстановки в SQL.
// SA-MP не имеет встроенной функции экранирования, поэтому удваиваем '.
stock Bank_Escape(const src[], dest[], destLen)
{
    new j = 0;
    for(new i = 0; src[i] != '\0' && j < destLen - 2; i++)
    {
        if(src[i] == '\'')
        {
            dest[j++] = '\'';
            dest[j++] = '\'';
        }
        else
        {
            dest[j++] = src[i];
        }
    }
    dest[j] = '\0';
}

// Форматирует сумму с разделителями тысяч: 1234567 -> "1 234 567"
stock Bank_FormatMoney(amount, dest[], destLen)
{
    new bool:negative = (amount < 0);
    new abs_amount = negative ? -amount : amount;

    new tmp[16];
    format(tmp, sizeof tmp, "%d", abs_amount);
    new tmpLen = strlen(tmp);

    new j = 0;
    if(negative && j < destLen - 1) dest[j++] = '-';

    // Пробел перед каждой группой из 3 цифр, считая с конца
    for(new i = 0; i < tmpLen && j < destLen - 1; i++)
    {
        if(i != 0 && (tmpLen - i) % 3 == 0 && j < destLen - 1)
            dest[j++] = ' ';
        dest[j++] = tmp[i];
    }
    dest[j] = '\0';
}

// Возвращает 1 если сумма принимается за валидную для операции.
stock Bank_IsValidAmount(amount)
{
    return (amount >= BANK_MIN_OPERATION && amount <= BANK_MAX_OPERATION);
}

// Cooldown: возвращает 1 если можно выполнять команду, иначе сообщает игроку.
stock Bank_CheckCooldown(playerid)
{
    new tick = GetTickCount();
    if(tick - gPlayer[playerid][bLastCmdTick] < BANK_CMD_COOLDOWN_MS)
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] Подождите немного перед следующей операцией.");
        return 0;
    }
    gPlayer[playerid][bLastCmdTick] = tick;
    return 1;
}

// Проверка прав банковского администратора (легко заменить на свою систему)
stock IsBankAdmin(playerid)
{
    return IsPlayerAdmin(playerid);
}

// Найти онлайн-игрока по точному совпадению имени (case-insensitive)
stock Bank_FindPlayerByName(const name[])
{
    new pname[MAX_PLAYER_NAME];
    for(new i = 0, j = GetMaxPlayers(); i < j; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        GetPlayerName(i, pname, sizeof pname);
        if(!strcmp(pname, name, true)) return i;
    }
    return INVALID_PLAYER_ID;
}

/* ============================================================================
 *                              SQLITE
 * ==========================================================================*/

// Создание таблиц при первом запуске
stock Bank_DB_CreateTables()
{
    if(gBankDB == DB:0) return 0;

    db_free_result(db_query(gBankDB,
        "CREATE TABLE IF NOT EXISTS bank_accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, player_name VARCHAR(24) UNIQUE NOT NULL, balance INTEGER DEFAULT 0, credit_amount INTEGER DEFAULT 0, credit_debt INTEGER DEFAULT 0, credit_daily INTEGER DEFAULT 0, credit_taken INTEGER DEFAULT 0, credit_next INTEGER DEFAULT 0, loan_amount INTEGER DEFAULT 0, loan_debt INTEGER DEFAULT 0, loan_taken INTEGER DEFAULT 0, loan_due INTEGER DEFAULT 0)"));

    db_free_result(db_query(gBankDB,
        "CREATE TABLE IF NOT EXISTS bank_history (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL, ts INTEGER NOT NULL, type INTEGER NOT NULL, amount INTEGER NOT NULL, note VARCHAR(64) DEFAULT '')"));
    return 1;
}

// Загрузка данных игрока (или создание пустого счёта)
stock Bank_DB_LoadPlayer(playerid)
{
    if(gBankDB == DB:0) return 0;

    new pname[MAX_PLAYER_NAME];
    Bank_GetName(playerid, pname, sizeof pname);
    if(pname[0] == '\0') return 0;

    new escaped[MAX_PLAYER_NAME * 2 + 1];
    Bank_Escape(pname, escaped, sizeof escaped);

    new query[256];
    format(query, sizeof query,
        "SELECT id,balance,credit_amount,credit_debt,credit_daily,credit_taken,credit_next,loan_amount,loan_debt,loan_taken,loan_due FROM bank_accounts WHERE player_name='%s' LIMIT 1",
        escaped);

    new DBResult:res = db_query(gBankDB, query);
    if(res && db_num_rows(res) > 0)
    {
        new buf[32];

        db_get_field_assoc(res, "id",            buf, sizeof buf); gPlayer[playerid][bAccountID]    = strval(buf);
        db_get_field_assoc(res, "balance",       buf, sizeof buf); gPlayer[playerid][bBalance]      = strval(buf);
        db_get_field_assoc(res, "credit_amount", buf, sizeof buf); gPlayer[playerid][bCreditAmount] = strval(buf);
        db_get_field_assoc(res, "credit_debt",   buf, sizeof buf); gPlayer[playerid][bCreditDebt]   = strval(buf);
        db_get_field_assoc(res, "credit_daily",  buf, sizeof buf); gPlayer[playerid][bCreditDaily]  = strval(buf);
        db_get_field_assoc(res, "credit_taken",  buf, sizeof buf); gPlayer[playerid][bCreditTaken]  = strval(buf);
        db_get_field_assoc(res, "credit_next",   buf, sizeof buf); gPlayer[playerid][bCreditNextPay]= strval(buf);
        db_get_field_assoc(res, "loan_amount",   buf, sizeof buf); gPlayer[playerid][bLoanAmount]   = strval(buf);
        db_get_field_assoc(res, "loan_debt",     buf, sizeof buf); gPlayer[playerid][bLoanDebt]     = strval(buf);
        db_get_field_assoc(res, "loan_taken",    buf, sizeof buf); gPlayer[playerid][bLoanTaken]    = strval(buf);
        db_get_field_assoc(res, "loan_due",      buf, sizeof buf); gPlayer[playerid][bLoanDue]      = strval(buf);
    }
    else
    {
        // Создаём новую запись
        format(query, sizeof query,
            "INSERT INTO bank_accounts (player_name) VALUES ('%s')", escaped);
        db_free_result(db_query(gBankDB, query));

        format(query, sizeof query,
            "SELECT id FROM bank_accounts WHERE player_name='%s' LIMIT 1", escaped);
        new DBResult:res2 = db_query(gBankDB, query);
        if(res2 && db_num_rows(res2) > 0)
        {
            new buf[32];
            db_get_field_assoc(res2, "id", buf, sizeof buf);
            gPlayer[playerid][bAccountID] = strval(buf);
        }
        if(res2) db_free_result(res2);
    }
    if(res) db_free_result(res);

    gPlayer[playerid][bLoaded] = 1;
    return 1;
}

// Сохранение данных игрока в БД
stock Bank_DB_SavePlayer(playerid)
{
    if(gBankDB == DB:0) return 0;
    if(!gPlayer[playerid][bLoaded]) return 0;
    if(gPlayer[playerid][bAccountID] <= 0) return 0;

    new query[512];
    format(query, sizeof query,
        "UPDATE bank_accounts SET balance=%d, credit_amount=%d, credit_debt=%d, credit_daily=%d, credit_taken=%d, credit_next=%d, loan_amount=%d, loan_debt=%d, loan_taken=%d, loan_due=%d WHERE id=%d",
        gPlayer[playerid][bBalance],
        gPlayer[playerid][bCreditAmount],
        gPlayer[playerid][bCreditDebt],
        gPlayer[playerid][bCreditDaily],
        gPlayer[playerid][bCreditTaken],
        gPlayer[playerid][bCreditNextPay],
        gPlayer[playerid][bLoanAmount],
        gPlayer[playerid][bLoanDebt],
        gPlayer[playerid][bLoanTaken],
        gPlayer[playerid][bLoanDue],
        gPlayer[playerid][bAccountID]);

    db_free_result(db_query(gBankDB, query));
    return 1;
}

// Сохраняет одну запись в историю операций
stock Bank_DB_AddHistory(playerid, type, amount, const note[])
{
    if(gBankDB == DB:0) return 0;
    if(gPlayer[playerid][bAccountID] <= 0) return 0;

    new escapedNote[160];
    Bank_Escape(note, escapedNote, sizeof escapedNote);

    new query[256];
    format(query, sizeof query,
        "INSERT INTO bank_history (account_id, ts, type, amount, note) VALUES (%d, %d, %d, %d, '%s')",
        gPlayer[playerid][bAccountID], gettime(), type, amount, escapedNote);
    db_free_result(db_query(gBankDB, query));
    return 1;
}

// Очистить историю по account_id (используется админкой)
stock Bank_DB_ClearHistory(accountid)
{
    if(gBankDB == DB:0) return 0;
    new query[128];
    format(query, sizeof query,
        "DELETE FROM bank_history WHERE account_id=%d", accountid);
    db_free_result(db_query(gBankDB, query));
    return 1;
}

/* ============================================================================
 *                          ОПЕРАЦИИ С НАЛИЧНЫМИ
 *                  (тонкая обёртка над GivePlayerMoney)
 * ==========================================================================*/

stock Bank_GiveCash(playerid, amount)
{
    GivePlayerMoney(playerid, amount);
}

stock Bank_TakeCash(playerid, amount)
{
    GivePlayerMoney(playerid, -amount);
}

stock Bank_GetCash(playerid)
{
    return GetPlayerMoney(playerid);
}

/* ============================================================================
 *                       ОПЕРАЦИИ БАНКОВСКОГО СЧЁТА
 * ==========================================================================*/

// Пополнение счёта наличными
stock Bank_Deposit(playerid, amount)
{
    if(!gPlayer[playerid][bLoaded])
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] Ваш счёт ещё не загружен, попробуйте через секунду.");
        return 0;
    }
    if(!Bank_IsValidAmount(amount))
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] Некорректная сумма.");
        return 0;
    }
    if(Bank_GetCash(playerid) < amount)
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] Недостаточно наличных.");
        return 0;
    }
    // Защита от переполнения (32-bit signed: ~2.14 млрд)
    if(gPlayer[playerid][bBalance] + amount < gPlayer[playerid][bBalance])
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] На счёте слишком много денег для пополнения.");
        return 0;
    }
    Bank_TakeCash(playerid, amount);
    gPlayer[playerid][bBalance] += amount;
    Bank_DB_SavePlayer(playerid);
    Bank_DB_AddHistory(playerid, HIST_DEPOSIT, amount, "Пополнение счёта");

    new msg[128], money[24];
    Bank_FormatMoney(amount, money, sizeof money);
    format(msg, sizeof msg, "[Банк] Вы пополнили счёт на $%s.", money);
    SendClientMessage(playerid, COLOR_BANK_INFO, msg);
    return 1;
}

// Снятие со счёта
stock Bank_Withdraw(playerid, amount)
{
    if(!gPlayer[playerid][bLoaded]) return 0;
    if(!Bank_IsValidAmount(amount))
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] Некорректная сумма.");
        return 0;
    }
    if(gPlayer[playerid][bBalance] < amount)
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] Недостаточно средств на счёте.");
        return 0;
    }
    gPlayer[playerid][bBalance] -= amount;
    Bank_GiveCash(playerid, amount);
    Bank_DB_SavePlayer(playerid);
    Bank_DB_AddHistory(playerid, HIST_WITHDRAW, amount, "Снятие со счёта");

    new msg[128], money[24];
    Bank_FormatMoney(amount, money, sizeof money);
    format(msg, sizeof msg, "[Банк] Вы сняли со счёта $%s.", money);
    SendClientMessage(playerid, COLOR_BANK_INFO, msg);
    return 1;
}

// Перевод с счёта на счёт другого игрока (с комиссией)
stock Bank_Transfer(playerid, targetid, amount)
{
    if(!gPlayer[playerid][bLoaded] || !gPlayer[targetid][bLoaded]) return 0;

    if(playerid == targetid)
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] Нельзя переводить деньги самому себе.");
        return 0;
    }
    if(!Bank_IsValidAmount(amount))
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] Некорректная сумма.");
        return 0;
    }
    new fee = (amount * BANK_TRANSFER_FEE_PERCENT) / 100;
    new total = amount + fee;
    if(gPlayer[playerid][bBalance] < total)
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] Недостаточно средств на счёте (с учётом комиссии).");
        return 0;
    }
    if(gPlayer[targetid][bBalance] + amount < gPlayer[targetid][bBalance])
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] У получателя слишком много денег на счёте.");
        return 0;
    }

    gPlayer[playerid][bBalance] -= total;
    gPlayer[targetid][bBalance] += amount;

    Bank_DB_SavePlayer(playerid);
    Bank_DB_SavePlayer(targetid);

    new senderName[MAX_PLAYER_NAME], targetName[MAX_PLAYER_NAME];
    Bank_GetName(playerid, senderName, sizeof senderName);
    Bank_GetName(targetid, targetName, sizeof targetName);

    new note[96];
    format(note, sizeof note, "Перевод -> %s (комиссия %d)", targetName, fee);
    Bank_DB_AddHistory(playerid, HIST_TRANSFER_OUT, amount, note);

    format(note, sizeof note, "Перевод от %s", senderName);
    Bank_DB_AddHistory(targetid, HIST_TRANSFER_IN, amount, note);

    new msg[160], moneyA[24], moneyF[24];
    Bank_FormatMoney(amount, moneyA, sizeof moneyA);
    Bank_FormatMoney(fee, moneyF, sizeof moneyF);

    format(msg, sizeof msg, "[Банк] Перевод $%s -> %s выполнен. Комиссия: $%s.",
        moneyA, targetName, moneyF);
    SendClientMessage(playerid, COLOR_BANK_INFO, msg);

    format(msg, sizeof msg, "[Банк] Вам пришёл перевод $%s от %s.",
        moneyA, senderName);
    SendClientMessage(targetid, COLOR_BANK_INFO, msg);
    return 1;
}

/* ============================================================================
 *                                КРЕДИТЫ
 * ==========================================================================*/

stock Bank_HasCredit(playerid)
{
    return gPlayer[playerid][bCreditDebt] > 0;
}

stock Bank_TakeCredit(playerid, amount)
{
    if(!gPlayer[playerid][bLoaded]) return 0;
    if(Bank_HasCredit(playerid))
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] У вас уже есть активный кредит.");
        return 0;
    }
    if(amount < BANK_CREDIT_MIN || amount > BANK_CREDIT_MAX)
    {
        new msg[160], minS[24], maxS[24];
        Bank_FormatMoney(BANK_CREDIT_MIN, minS, sizeof minS);
        Bank_FormatMoney(BANK_CREDIT_MAX, maxS, sizeof maxS);
        format(msg, sizeof msg,
            "[Банк] Сумма кредита должна быть в диапазоне $%s — $%s.", minS, maxS);
        SendClientMessage(playerid, COLOR_BANK_ERROR, msg);
        return 0;
    }
    new total = amount + (amount * BANK_CREDIT_PERCENT) / 100;
    new daily = total / BANK_CREDIT_DAYS;
    if(daily < 1) daily = 1;

    gPlayer[playerid][bCreditAmount]  = amount;
    gPlayer[playerid][bCreditDebt]    = total;
    gPlayer[playerid][bCreditDaily]   = daily;
    gPlayer[playerid][bCreditTaken]   = gettime();
    gPlayer[playerid][bCreditNextPay] = gettime() + BANK_CREDIT_DAY_SECONDS;

    // Деньги получает игрок на банковский счёт (так безопаснее)
    gPlayer[playerid][bBalance] += amount;

    Bank_DB_SavePlayer(playerid);

    new note[96], moneyA[24], moneyT[24];
    Bank_FormatMoney(amount, moneyA, sizeof moneyA);
    Bank_FormatMoney(total, moneyT, sizeof moneyT);
    format(note, sizeof note, "Кредит %d дн., итого %d", BANK_CREDIT_DAYS, total);
    Bank_DB_AddHistory(playerid, HIST_CREDIT_TAKEN, amount, note);

    new msg[200];
    format(msg, sizeof msg,
        "[Банк] Выдан кредит $%s. Долг с процентами: $%s. Срок: %d дн.",
        moneyA, moneyT, BANK_CREDIT_DAYS);
    SendClientMessage(playerid, COLOR_BANK_INFO, msg);
    return 1;
}

stock Bank_PayCredit(playerid, amount)
{
    if(!gPlayer[playerid][bLoaded]) return 0;
    if(!Bank_HasCredit(playerid))
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] У вас нет активного кредита.");
        return 0;
    }
    if(!Bank_IsValidAmount(amount))
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] Некорректная сумма платежа.");
        return 0;
    }
    if(amount > gPlayer[playerid][bCreditDebt])
        amount = gPlayer[playerid][bCreditDebt];

    if(gPlayer[playerid][bBalance] < amount)
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] Недостаточно средств на счёте для платежа.");
        return 0;
    }

    gPlayer[playerid][bBalance]    -= amount;
    gPlayer[playerid][bCreditDebt] -= amount;

    if(gPlayer[playerid][bCreditDebt] <= 0)
    {
        // Кредит закрыт
        gPlayer[playerid][bCreditAmount]  = 0;
        gPlayer[playerid][bCreditDebt]    = 0;
        gPlayer[playerid][bCreditDaily]   = 0;
        gPlayer[playerid][bCreditTaken]   = 0;
        gPlayer[playerid][bCreditNextPay] = 0;
        SendClientMessage(playerid, COLOR_BANK_INFO,
            "[Банк] Кредит полностью погашен!");
    }
    else
    {
        // Сдвигаем дату следующего платежа
        gPlayer[playerid][bCreditNextPay] = gettime() + BANK_CREDIT_DAY_SECONDS;
    }

    Bank_DB_SavePlayer(playerid);
    Bank_DB_AddHistory(playerid, HIST_CREDIT_PAID, amount, "Платёж по кредиту");

    new msg[160], moneyA[24], moneyD[24];
    Bank_FormatMoney(amount, moneyA, sizeof moneyA);
    Bank_FormatMoney(gPlayer[playerid][bCreditDebt], moneyD, sizeof moneyD);
    format(msg, sizeof msg,
        "[Банк] Принято $%s. Остаток долга по кредиту: $%s.", moneyA, moneyD);
    SendClientMessage(playerid, COLOR_BANK_INFO, msg);
    return 1;
}

// Принудительное закрытие кредита (админ)
stock Bank_AdminCloseCredit(targetid)
{
    if(!gPlayer[targetid][bLoaded]) return 0;
    if(!Bank_HasCredit(targetid)) return 0;
    new amount = gPlayer[targetid][bCreditDebt];
    gPlayer[targetid][bCreditAmount]  = 0;
    gPlayer[targetid][bCreditDebt]    = 0;
    gPlayer[targetid][bCreditDaily]   = 0;
    gPlayer[targetid][bCreditTaken]   = 0;
    gPlayer[targetid][bCreditNextPay] = 0;
    Bank_DB_SavePlayer(targetid);
    Bank_DB_AddHistory(targetid, HIST_ADMIN, amount, "Админ закрыл кредит");
    SendClientMessage(targetid, COLOR_BANK_INFO,
        "[Банк] Администрация банка закрыла ваш кредит.");
    return 1;
}

/* ============================================================================
 *                                  ЗАЙМЫ
 * ==========================================================================*/

stock Bank_HasLoan(playerid)
{
    return gPlayer[playerid][bLoanDebt] > 0;
}

stock Bank_TakeLoan(playerid, amount)
{
    if(!gPlayer[playerid][bLoaded]) return 0;
    if(Bank_HasLoan(playerid))
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] У вас уже есть активный займ.");
        return 0;
    }
    if(amount < BANK_LOAN_MIN || amount > BANK_LOAN_MAX)
    {
        new msg[160], minS[24], maxS[24];
        Bank_FormatMoney(BANK_LOAN_MIN, minS, sizeof minS);
        Bank_FormatMoney(BANK_LOAN_MAX, maxS, sizeof maxS);
        format(msg, sizeof msg,
            "[Банк] Сумма займа должна быть в диапазоне $%s — $%s.", minS, maxS);
        SendClientMessage(playerid, COLOR_BANK_ERROR, msg);
        return 0;
    }
    new total = amount + (amount * BANK_LOAN_PERCENT) / 100;
    gPlayer[playerid][bLoanAmount] = amount;
    gPlayer[playerid][bLoanDebt]   = total;
    gPlayer[playerid][bLoanTaken]  = gettime();
    gPlayer[playerid][bLoanDue]    = gettime() + BANK_LOAN_DAYS * BANK_LOAN_DAY_SECONDS;

    // Займ выдаётся НАЛИЧНЫМИ — это микрокредит
    Bank_GiveCash(playerid, amount);

    Bank_DB_SavePlayer(playerid);
    Bank_DB_AddHistory(playerid, HIST_LOAN_TAKEN, amount, "Займ выдан наличными");

    new msg[200], moneyA[24], moneyT[24];
    Bank_FormatMoney(amount, moneyA, sizeof moneyA);
    Bank_FormatMoney(total, moneyT, sizeof moneyT);
    format(msg, sizeof msg,
        "[Банк] Выдан займ $%s наличными. К возврату: $%s. Срок: %d дн.",
        moneyA, moneyT, BANK_LOAN_DAYS);
    SendClientMessage(playerid, COLOR_BANK_INFO, msg);
    return 1;
}

stock Bank_PayLoan(playerid, amount)
{
    if(!gPlayer[playerid][bLoaded]) return 0;
    if(!Bank_HasLoan(playerid))
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] У вас нет активного займа.");
        return 0;
    }
    if(!Bank_IsValidAmount(amount))
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] Некорректная сумма платежа.");
        return 0;
    }
    if(amount > gPlayer[playerid][bLoanDebt])
        amount = gPlayer[playerid][bLoanDebt];

    // Платим с банковского счёта
    if(gPlayer[playerid][bBalance] < amount)
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] Недостаточно средств на счёте.");
        return 0;
    }
    gPlayer[playerid][bBalance]  -= amount;
    gPlayer[playerid][bLoanDebt] -= amount;

    if(gPlayer[playerid][bLoanDebt] <= 0)
    {
        gPlayer[playerid][bLoanAmount] = 0;
        gPlayer[playerid][bLoanDebt]   = 0;
        gPlayer[playerid][bLoanTaken]  = 0;
        gPlayer[playerid][bLoanDue]    = 0;
        SendClientMessage(playerid, COLOR_BANK_INFO,
            "[Банк] Займ полностью погашен!");
    }

    Bank_DB_SavePlayer(playerid);
    Bank_DB_AddHistory(playerid, HIST_LOAN_PAID, amount, "Платёж по займу");

    new msg[160], moneyA[24], moneyD[24];
    Bank_FormatMoney(amount, moneyA, sizeof moneyA);
    Bank_FormatMoney(gPlayer[playerid][bLoanDebt], moneyD, sizeof moneyD);
    format(msg, sizeof msg,
        "[Банк] Принято $%s. Остаток по займу: $%s.", moneyA, moneyD);
    SendClientMessage(playerid, COLOR_BANK_INFO, msg);
    return 1;
}

stock Bank_AdminCloseLoan(targetid)
{
    if(!gPlayer[targetid][bLoaded]) return 0;
    if(!Bank_HasLoan(targetid)) return 0;
    new amount = gPlayer[targetid][bLoanDebt];
    gPlayer[targetid][bLoanAmount] = 0;
    gPlayer[targetid][bLoanDebt]   = 0;
    gPlayer[targetid][bLoanTaken]  = 0;
    gPlayer[targetid][bLoanDue]    = 0;
    Bank_DB_SavePlayer(targetid);
    Bank_DB_AddHistory(targetid, HIST_ADMIN, amount, "Админ закрыл займ");
    SendClientMessage(targetid, COLOR_BANK_INFO,
        "[Банк] Администрация банка закрыла ваш займ.");
    return 1;
}

/* ============================================================================
 *                ТАЙМЕР: проверка просрочек кредитов и займов
 *  Срабатывает раз в минуту. Если у игрока истёк срок очередного платежа —
 *  списывается штраф (с банковского счёта или с долга). Если игрок офлайн,
 *  при следующем входе долг уже учтёт штрафы.
 * ==========================================================================*/

public Bank_OnPaymentTimer()
{
    new now = gettime();
    for(new i = 0, j = GetMaxPlayers(); i < j; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        if(!gPlayer[i][bLoaded]) continue;

        // ----- Кредит: ежедневный платёж и штраф за просрочку -------------
        if(gPlayer[i][bCreditDebt] > 0 &&
           gPlayer[i][bCreditNextPay] != 0 &&
           now >= gPlayer[i][bCreditNextPay])
        {
            new daily = gPlayer[i][bCreditDaily];
            if(daily > gPlayer[i][bCreditDebt]) daily = gPlayer[i][bCreditDebt];

            if(gPlayer[i][bBalance] >= daily)
            {
                // Автосписание ежедневного платежа
                gPlayer[i][bBalance]    -= daily;
                gPlayer[i][bCreditDebt] -= daily;
                Bank_DB_AddHistory(i, HIST_CREDIT_PAID, daily,
                    "Автоплатёж по кредиту");
                SendClientMessage(i, COLOR_BANK_INFO,
                    "[Банк] Автоматически списан ежедневный платёж по кредиту.");

                if(gPlayer[i][bCreditDebt] <= 0)
                {
                    gPlayer[i][bCreditAmount]  = 0;
                    gPlayer[i][bCreditDebt]    = 0;
                    gPlayer[i][bCreditDaily]   = 0;
                    gPlayer[i][bCreditTaken]   = 0;
                    gPlayer[i][bCreditNextPay] = 0;
                    SendClientMessage(i, COLOR_BANK_INFO,
                        "[Банк] Кредит полностью погашен (автоматически)!");
                }
                else
                {
                    gPlayer[i][bCreditNextPay] = now + BANK_CREDIT_DAY_SECONDS;
                }
            }
            else
            {
                // Не хватает на ежедневный платёж — штраф
                gPlayer[i][bCreditDebt] += BANK_CREDIT_PENALTY;
                gPlayer[i][bCreditNextPay] = now + BANK_CREDIT_DAY_SECONDS;
                Bank_DB_AddHistory(i, HIST_PENALTY, BANK_CREDIT_PENALTY,
                    "Штраф за просрочку кредита");
                new msg[160], pen[24];
                Bank_FormatMoney(BANK_CREDIT_PENALTY, pen, sizeof pen);
                format(msg, sizeof msg,
                    "[Банк] Просрочка платежа по кредиту! Штраф: $%s.", pen);
                SendClientMessage(i, COLOR_BANK_ERROR, msg);
            }
            Bank_DB_SavePlayer(i);
        }

        // ----- Займ: проверка истечения срока -----------------------------
        if(gPlayer[i][bLoanDebt] > 0 &&
           gPlayer[i][bLoanDue] != 0 &&
           now >= gPlayer[i][bLoanDue])
        {
            // Срок прошёл — начисляем штраф и сдвигаем дедлайн на сутки
            gPlayer[i][bLoanDebt] += BANK_LOAN_PENALTY;
            gPlayer[i][bLoanDue]   = now + BANK_LOAN_DAY_SECONDS;
            Bank_DB_AddHistory(i, HIST_PENALTY, BANK_LOAN_PENALTY,
                "Штраф за просрочку займа");
            new msg[160], pen[24];
            Bank_FormatMoney(BANK_LOAN_PENALTY, pen, sizeof pen);
            format(msg, sizeof msg,
                "[Банк] Просрочка возврата займа! Штраф: $%s.", pen);
            SendClientMessage(i, COLOR_BANK_ERROR, msg);
            Bank_DB_SavePlayer(i);
        }
    }
    return 1;
}

/* ============================================================================
 *                          ДИАЛОГИ — ПОКАЗ
 * ==========================================================================*/

stock Bank_ShowMainMenu(playerid)
{
    new info[512];
    format(info, sizeof info,
        "{FFFFFF}Добро пожаловать в банк, выберите операцию:\n{33CCFF}Баланс счёта\n{33AA33}Пополнить счёт\n{FF8800}Снять со счёта\n{FFFF00}Перевод другому игроку (комиссия %d%%)\n{AAAAFF}История операций\n{FFAAAA}Кредиты\n{AAFFAA}Займы",
        BANK_TRANSFER_FEE_PERCENT);
    ShowPlayerDialog(playerid, DIALOG_BANK_MAIN, DIALOG_STYLE_LIST,
        "Банк — Главное меню", info, "Выбрать", "Закрыть");
}

stock Bank_ShowBalance(playerid)
{
    new info[512], cash[24], bank[24], debtC[24], debtL[24];
    Bank_FormatMoney(Bank_GetCash(playerid),     cash,  sizeof cash);
    Bank_FormatMoney(gPlayer[playerid][bBalance],bank,  sizeof bank);
    Bank_FormatMoney(gPlayer[playerid][bCreditDebt], debtC, sizeof debtC);
    Bank_FormatMoney(gPlayer[playerid][bLoanDebt],   debtL, sizeof debtL);
    format(info, sizeof info,
        "{FFFFFF}Наличные:\t{33AA33}$%s\n{FFFFFF}На счёте:\t{33AA33}$%s\n{FFFFFF}Долг по кредиту:\t{CC2222}$%s\n{FFFFFF}Долг по займу:\t{CC2222}$%s",
        cash, bank, debtC, debtL);
    ShowPlayerDialog(playerid, DIALOG_BANK_BALANCE, DIALOG_STYLE_MSGBOX,
        "Банк — Баланс", info, "Назад", "");
}

stock Bank_ShowDepositInput(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_BANK_DEPOSIT, DIALOG_STYLE_INPUT,
        "Банк — Пополнение",
        "Введите сумму пополнения наличными:",
        "Внести", "Отмена");
}

stock Bank_ShowWithdrawInput(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_BANK_WITHDRAW, DIALOG_STYLE_INPUT,
        "Банк — Снятие",
        "Введите сумму для снятия со счёта:",
        "Снять", "Отмена");
}

stock Bank_ShowTransferTargetInput(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_BANK_TRANSFER_ID, DIALOG_STYLE_INPUT,
        "Банк — Перевод (1/2)",
        "Введите ID получателя:",
        "Далее", "Отмена");
}

stock Bank_ShowTransferSumInput(playerid)
{
    new targetid = gPlayer[playerid][bTransferTarget];
    new tname[MAX_PLAYER_NAME];
    Bank_GetName(targetid, tname, sizeof tname);

    new info[160];
    format(info, sizeof info,
        "Получатель: %s (ID %d)\nКомиссия перевода: %d%%\nВведите сумму:",
        tname, targetid, BANK_TRANSFER_FEE_PERCENT);
    ShowPlayerDialog(playerid, DIALOG_BANK_TRANSFER_SUM, DIALOG_STYLE_INPUT,
        "Банк — Перевод (2/2)", info, "Перевести", "Отмена");
}

stock Bank_ShowHistory(playerid)
{
    if(gBankDB == DB:0 || gPlayer[playerid][bAccountID] <= 0)
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] История недоступна.");
        return;
    }
    new query[256];
    format(query, sizeof query,
        "SELECT ts,type,amount,note FROM bank_history WHERE account_id=%d ORDER BY id DESC LIMIT %d",
        gPlayer[playerid][bAccountID], BANK_HISTORY_LIMIT);

    new DBResult:res = db_query(gBankDB, query);
    new info[2048];
    info[0] = '\0';

    if(res && db_num_rows(res) > 0)
    {
        new buf[64], note[64], money[24];
        new ts, type, amount;
        new line[256];
        do
        {
            db_get_field_assoc(res, "ts",     buf,  sizeof buf);  ts     = strval(buf);
            db_get_field_assoc(res, "type",   buf,  sizeof buf);  type   = strval(buf);
            db_get_field_assoc(res, "amount", buf,  sizeof buf);  amount = strval(buf);
            db_get_field_assoc(res, "note",   note, sizeof note);

            Bank_FormatMoney(amount, money, sizeof money);

            new typeStr[24];
            switch(type)
            {
                case HIST_DEPOSIT:      typeStr = "Пополнение";
                case HIST_WITHDRAW:     typeStr = "Снятие";
                case HIST_TRANSFER_OUT: typeStr = "Перевод -";
                case HIST_TRANSFER_IN:  typeStr = "Перевод +";
                case HIST_CREDIT_TAKEN: typeStr = "Кредит +";
                case HIST_CREDIT_PAID:  typeStr = "Кредит -";
                case HIST_LOAN_TAKEN:   typeStr = "Займ +";
                case HIST_LOAN_PAID:    typeStr = "Займ -";
                case HIST_PENALTY:      typeStr = "Штраф";
                case HIST_ADMIN:        typeStr = "Админ";
                default:                typeStr = "?";
            }

            // Возраст операции (в часах) — без полноценного strftime
            new ageHours = (gettime() - ts) / 3600;
            format(line, sizeof line, "{AAAAAA}-%dч {FFFFFF}%s\t{33CCFF}$%s\t{CCCCCC}%s\n",
                ageHours, typeStr, money, note);
            strcat(info, line, sizeof info);
        }
        while(db_next_row(res));
    }
    else
    {
        strcat(info, "{AAAAAA}История пуста.", sizeof info);
    }
    if(res) db_free_result(res);

    ShowPlayerDialog(playerid, DIALOG_BANK_HISTORY, DIALOG_STYLE_MSGBOX,
        "Банк — История операций", info, "Назад", "");
}

stock Bank_ShowCreditMenu(playerid)
{
    new info[256];
    format(info, sizeof info,
        "{FFFFFF}Кредиты — выберите действие:\n{33AA33}Взять кредит (макс. $%d, %d%%, %d дн.)\n{FF8800}Погасить кредит\n{33CCFF}Информация по кредиту",
        BANK_CREDIT_MAX, BANK_CREDIT_PERCENT, BANK_CREDIT_DAYS);
    ShowPlayerDialog(playerid, DIALOG_CREDIT_MAIN, DIALOG_STYLE_LIST,
        "Банк — Кредиты", info, "Выбрать", "Закрыть");
}

stock Bank_ShowCreditTake(playerid)
{
    new info[256];
    format(info, sizeof info,
        "Введите сумму кредита.\nМинимум: $%d, максимум: $%d.\nПроцент: %d%%, срок: %d дн.",
        BANK_CREDIT_MIN, BANK_CREDIT_MAX,
        BANK_CREDIT_PERCENT, BANK_CREDIT_DAYS);
    ShowPlayerDialog(playerid, DIALOG_CREDIT_TAKE, DIALOG_STYLE_INPUT,
        "Кредит — Взять", info, "Взять", "Отмена");
}

stock Bank_ShowCreditPay(playerid)
{
    if(!Bank_HasCredit(playerid))
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] У вас нет активного кредита.");
        return;
    }
    new info[160], debt[24];
    Bank_FormatMoney(gPlayer[playerid][bCreditDebt], debt, sizeof debt);
    format(info, sizeof info,
        "Текущий долг: $%s.\nВведите сумму платежа:", debt);
    ShowPlayerDialog(playerid, DIALOG_CREDIT_PAY, DIALOG_STYLE_INPUT,
        "Кредит — Погашение", info, "Оплатить", "Отмена");
}

stock Bank_ShowCreditInfo(playerid)
{
    new info[512];
    if(!Bank_HasCredit(playerid))
    {
        format(info, sizeof info, "{FFFFFF}У вас нет активного кредита.");
    }
    else
    {
        new amt[24], debt[24], dly[24];
        Bank_FormatMoney(gPlayer[playerid][bCreditAmount], amt,  sizeof amt);
        Bank_FormatMoney(gPlayer[playerid][bCreditDebt],   debt, sizeof debt);
        Bank_FormatMoney(gPlayer[playerid][bCreditDaily],  dly,  sizeof dly);

        new now = gettime();
        new untilNext = gPlayer[playerid][bCreditNextPay] - now;
        if(untilNext < 0) untilNext = 0;
        new hoursLeft = untilNext / 3600;

        format(info, sizeof info,
            "{FFFFFF}Сумма кредита:\t{33AA33}$%s\n{FFFFFF}Остаток долга:\t{CC2222}$%s\n{FFFFFF}Ежедневный платёж:\t{FF8800}$%s\n{FFFFFF}До следующего платежа:\t{33CCFF}~%d ч.",
            amt, debt, dly, hoursLeft);
    }
    ShowPlayerDialog(playerid, DIALOG_CREDIT_INFO, DIALOG_STYLE_MSGBOX,
        "Кредит — Информация", info, "Назад", "");
}

stock Bank_ShowLoanMenu(playerid)
{
    new info[256];
    format(info, sizeof info,
        "{FFFFFF}Займы — быстро, дорого, на короткий срок.\n{33AA33}Взять займ (макс. $%d, %d%%, %d дн.)\n{FF8800}Погасить займ\n{33CCFF}Информация по займу",
        BANK_LOAN_MAX, BANK_LOAN_PERCENT, BANK_LOAN_DAYS);
    ShowPlayerDialog(playerid, DIALOG_LOAN_MAIN, DIALOG_STYLE_LIST,
        "Банк — Займы", info, "Выбрать", "Закрыть");
}

stock Bank_ShowLoanTake(playerid)
{
    new info[256];
    format(info, sizeof info,
        "Введите сумму займа.\nМинимум: $%d, максимум: $%d.\nПроцент: %d%%, срок: %d дн.",
        BANK_LOAN_MIN, BANK_LOAN_MAX, BANK_LOAN_PERCENT, BANK_LOAN_DAYS);
    ShowPlayerDialog(playerid, DIALOG_LOAN_TAKE, DIALOG_STYLE_INPUT,
        "Займ — Взять", info, "Взять", "Отмена");
}

stock Bank_ShowLoanPay(playerid)
{
    if(!Bank_HasLoan(playerid))
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] У вас нет активного займа.");
        return;
    }
    new info[160], debt[24];
    Bank_FormatMoney(gPlayer[playerid][bLoanDebt], debt, sizeof debt);
    format(info, sizeof info,
        "Текущий долг по займу: $%s.\nВведите сумму платежа:", debt);
    ShowPlayerDialog(playerid, DIALOG_LOAN_PAY, DIALOG_STYLE_INPUT,
        "Займ — Погашение", info, "Оплатить", "Отмена");
}

stock Bank_ShowLoanInfo(playerid)
{
    new info[512];
    if(!Bank_HasLoan(playerid))
    {
        format(info, sizeof info, "{FFFFFF}У вас нет активного займа.");
    }
    else
    {
        new amt[24], debt[24];
        Bank_FormatMoney(gPlayer[playerid][bLoanAmount], amt,  sizeof amt);
        Bank_FormatMoney(gPlayer[playerid][bLoanDebt],   debt, sizeof debt);

        new now = gettime();
        new untilDue = gPlayer[playerid][bLoanDue] - now;
        if(untilDue < 0) untilDue = 0;
        new hoursLeft = untilDue / 3600;

        format(info, sizeof info,
            "{FFFFFF}Сумма займа:\t{33AA33}$%s\n{FFFFFF}К возврату:\t{CC2222}$%s\n{FFFFFF}До дедлайна:\t{33CCFF}~%d ч.",
            amt, debt, hoursLeft);
    }
    ShowPlayerDialog(playerid, DIALOG_LOAN_INFO, DIALOG_STYLE_MSGBOX,
        "Займ — Информация", info, "Назад", "");
}

stock Bank_ShowAdminMenu(playerid)
{
    if(!IsBankAdmin(playerid))
    {
        SendClientMessage(playerid, COLOR_BANK_ERROR,
            "[Банк] У вас нет прав администратора банка.");
        return;
    }
    ShowPlayerDialog(playerid, DIALOG_ADMIN_MAIN, DIALOG_STYLE_LIST,
        "Банк — Админ-меню",
        "{FFFFFF}Просмотр счёта игрока\n{33AA33}Положить деньги на счёт игроку\n{FF8800}Снять деньги со счёта игрока\n{33CCFF}Выдать кредит игроку\n{CC2222}Принудительно закрыть кредит\n{CC2222}Принудительно закрыть займ\n{AAAAAA}Очистить историю игрока",
        "Выбрать", "Закрыть");
}

stock Bank_ShowAdminTargetInput(playerid)
{
    ShowPlayerDialog(playerid, DIALOG_ADMIN_TARGET_ID, DIALOG_STYLE_INPUT,
        "Админ — выбор игрока",
        "Введите ID игрока, над счётом которого совершить операцию:",
        "Далее", "Отмена");
}

stock Bank_ShowAdminAmountInput(playerid)
{
    new targetid = gPlayer[playerid][bAdminTarget];
    new tname[MAX_PLAYER_NAME];
    Bank_GetName(targetid, tname, sizeof tname);

    new title[64], info[160];
    switch(gPlayer[playerid][bAdminAction])
    {
        case ADM_ACT_GIVE_MONEY:  title = "Админ — Положить на счёт";
        case ADM_ACT_TAKE_MONEY:  title = "Админ — Снять со счёта";
        case ADM_ACT_GIVE_CREDIT: title = "Админ — Выдать кредит";
        default: title = "Админ — Сумма";
    }
    format(info, sizeof info, "Игрок: %s (ID %d)\nВведите сумму:", tname, targetid);
    ShowPlayerDialog(playerid, DIALOG_ADMIN_INPUT, DIALOG_STYLE_INPUT,
        title, info, "Подтвердить", "Отмена");
}

stock Bank_ShowAdminTargetView(playerid, targetid)
{
    new info[512];
    new bal[24], cdebt[24], ldebt[24];
    Bank_FormatMoney(gPlayer[targetid][bBalance],    bal,   sizeof bal);
    Bank_FormatMoney(gPlayer[targetid][bCreditDebt], cdebt, sizeof cdebt);
    Bank_FormatMoney(gPlayer[targetid][bLoanDebt],   ldebt, sizeof ldebt);

    new tname[MAX_PLAYER_NAME];
    Bank_GetName(targetid, tname, sizeof tname);

    format(info, sizeof info,
        "{FFFFFF}Игрок: {33CCFF}%s {FFFFFF}(ID %d)\n{FFFFFF}Счёт:\t{33AA33}$%s\n{FFFFFF}Долг кредит:\t{CC2222}$%s\n{FFFFFF}Долг займ:\t{CC2222}$%s",
        tname, targetid, bal, cdebt, ldebt);
    ShowPlayerDialog(playerid, DIALOG_BANK_BALANCE, DIALOG_STYLE_MSGBOX,
        "Админ — Просмотр счёта", info, "ОК", "");
}

/* ============================================================================
 *                          СОЗДАНИЕ ПИКАПОВ И 3D
 * ==========================================================================*/

stock Bank_CreatePickups()
{
    gBankPickup = CreatePickup(BANK_PICKUP_MODEL, 1,
        BANK_PICKUP_X, BANK_PICKUP_Y, BANK_PICKUP_Z, -1);
    gBankLabel = Create3DTextLabel(
        "Банк\n/bank — открыть меню",
        COLOR_BANK_LABEL,
        BANK_PICKUP_X, BANK_PICKUP_Y, BANK_PICKUP_Z + 0.6,
        15.0, 0, 1);

    gAtmPickup = CreatePickup(ATM_PICKUP_MODEL, 1,
        ATM_PICKUP_X, ATM_PICKUP_Y, ATM_PICKUP_Z, -1);
    gAtmLabel = Create3DTextLabel(
        "Банкомат\n/atm — операции со счётом",
        COLOR_BANK_LABEL,
        ATM_PICKUP_X, ATM_PICKUP_Y, ATM_PICKUP_Z + 0.6,
        15.0, 0, 1);

    gCreditPickup = CreatePickup(CREDIT_PICKUP_MODEL, 1,
        CREDIT_PICKUP_X, CREDIT_PICKUP_Y, CREDIT_PICKUP_Z, -1);
    gCreditLabel = Create3DTextLabel(
        "Кредитный отдел\n/credit /loan — кредиты и займы",
        COLOR_BANK_LABEL,
        CREDIT_PICKUP_X, CREDIT_PICKUP_Y, CREDIT_PICKUP_Z + 0.6,
        15.0, 0, 1);
}

stock Bank_DestroyPickups()
{
    DestroyPickup(gBankPickup);
    DestroyPickup(gAtmPickup);
    DestroyPickup(gCreditPickup);
    Delete3DTextLabel(gBankLabel);
    Delete3DTextLabel(gAtmLabel);
    Delete3DTextLabel(gCreditLabel);
}

/* ============================================================================
 *                              КОЛБЭКИ
 * ==========================================================================*/

public OnFilterScriptInit()
{
    print("======================================================");
    print("    bank_system.pwn  — банк, кредиты, займы");
    print("    Загрузка...");
    print("======================================================");

    gBankDB = db_open(BANK_DB_FILE);
    if(gBankDB == DB:0)
    {
        print("[Банк][ОШИБКА] Не удалось открыть SQLite-базу!");
    }
    else
    {
        Bank_DB_CreateTables();
        print("[Банк] База данных открыта и инициализирована.");
    }

    Bank_CreatePickups();

    // Таймер раз в 60 секунд проверяет просрочки
    gPaymentTimer = SetTimer("Bank_OnPaymentTimer", 60 * 1000, true);

    // Загружаем уже подключённых игроков (на случай /rcon reloadfs)
    for(new i = 0, j = GetMaxPlayers(); i < j; i++)
    {
        if(IsPlayerConnected(i)) Bank_DB_LoadPlayer(i);
    }

    print("[Банк] Готов к работе.");
    return 1;
}

public OnFilterScriptExit()
{
    KillTimer(gPaymentTimer);
    Bank_DestroyPickups();

    // Сохраняем всех онлайн-игроков
    for(new i = 0, j = GetMaxPlayers(); i < j; i++)
    {
        if(IsPlayerConnected(i) && gPlayer[i][bLoaded])
            Bank_DB_SavePlayer(i);
    }

    if(gBankDB != DB:0)
    {
        db_close(gBankDB);
        gBankDB = DB:0;
    }
    print("[Банк] Filterscript выгружен, данные сохранены.");
    return 1;
}

public OnPlayerConnect(playerid)
{
    // Сбрасываем структуру через присваивание пустого массива.
    new emptyData[E_BANK_PLAYER];
    gPlayer[playerid] = emptyData;
    gPlayer[playerid][bTransferTarget] = INVALID_PLAYER_ID;
    gPlayer[playerid][bAdminTarget]    = INVALID_PLAYER_ID;

    Bank_DB_LoadPlayer(playerid);

    SendClientMessage(playerid, COLOR_BANK_INFO,
        "[Банк] Команды: /bank /atm /credit /loan /paycredit /payloan");
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    if(gPlayer[playerid][bLoaded]) Bank_DB_SavePlayer(playerid);
    gPlayer[playerid][bLoaded] = 0;
    return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
    if(pickupid == gBankPickup)        Bank_ShowMainMenu(playerid);
    else if(pickupid == gAtmPickup)    Bank_ShowMainMenu(playerid);
    else if(pickupid == gCreditPickup) Bank_ShowCreditMenu(playerid);
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if(!strcmp(cmdtext, "/bank", true))
    {
        if(!Bank_CheckCooldown(playerid)) return 1;
        Bank_ShowMainMenu(playerid);
        return 1;
    }
    if(!strcmp(cmdtext, "/atm", true))
    {
        if(!Bank_CheckCooldown(playerid)) return 1;
        Bank_ShowMainMenu(playerid);
        return 1;
    }
    if(!strcmp(cmdtext, "/credit", true))
    {
        if(!Bank_CheckCooldown(playerid)) return 1;
        Bank_ShowCreditMenu(playerid);
        return 1;
    }
    if(!strcmp(cmdtext, "/loan", true))
    {
        if(!Bank_CheckCooldown(playerid)) return 1;
        Bank_ShowLoanMenu(playerid);
        return 1;
    }
    if(!strcmp(cmdtext, "/bankadmin", true))
    {
        if(!Bank_CheckCooldown(playerid)) return 1;
        Bank_ShowAdminMenu(playerid);
        return 1;
    }
    if(!strcmp(cmdtext, "/paycredit", true, 10))
    {
        if(!Bank_CheckCooldown(playerid)) return 1;
        if(strlen(cmdtext) <= 11)
        {
            SendClientMessage(playerid, COLOR_BANK_USAGE,
                "[Использование] /paycredit [сумма]");
            return 1;
        }
        new sum = strval(cmdtext[11]);
        Bank_PayCredit(playerid, sum);
        return 1;
    }
    if(!strcmp(cmdtext, "/payloan", true, 8))
    {
        if(!Bank_CheckCooldown(playerid)) return 1;
        if(strlen(cmdtext) <= 9)
        {
            SendClientMessage(playerid, COLOR_BANK_USAGE,
                "[Использование] /payloan [сумма]");
            return 1;
        }
        new sum = strval(cmdtext[9]);
        Bank_PayLoan(playerid, sum);
        return 1;
    }
    return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        // ----- Главное меню банка ----------------------------------------
        case DIALOG_BANK_MAIN:
        {
            if(!response) return 1;
            switch(listitem)
            {
                case 0: Bank_ShowBalance(playerid);
                case 1: Bank_ShowDepositInput(playerid);
                case 2: Bank_ShowWithdrawInput(playerid);
                case 3: Bank_ShowTransferTargetInput(playerid);
                case 4: Bank_ShowHistory(playerid);
                case 5: Bank_ShowCreditMenu(playerid);
                case 6: Bank_ShowLoanMenu(playerid);
            }
            return 1;
        }

        case DIALOG_BANK_BALANCE:
        {
            // Кнопка "Назад" возвращает в главное меню
            if(response) Bank_ShowMainMenu(playerid);
            return 1;
        }

        case DIALOG_BANK_DEPOSIT:
        {
            if(!response) return 1;
            new amount = strval(inputtext);
            Bank_Deposit(playerid, amount);
            return 1;
        }

        case DIALOG_BANK_WITHDRAW:
        {
            if(!response) return 1;
            new amount = strval(inputtext);
            Bank_Withdraw(playerid, amount);
            return 1;
        }

        case DIALOG_BANK_TRANSFER_ID:
        {
            if(!response) return 1;
            new targetid = strval(inputtext);
            if(targetid < 0 || targetid >= GetMaxPlayers() || !IsPlayerConnected(targetid))
            {
                SendClientMessage(playerid, COLOR_BANK_ERROR,
                    "[Банк] Игрок с таким ID не найден.");
                return 1;
            }
            if(targetid == playerid)
            {
                SendClientMessage(playerid, COLOR_BANK_ERROR,
                    "[Банк] Нельзя переводить деньги самому себе.");
                return 1;
            }
            gPlayer[playerid][bTransferTarget] = targetid;
            Bank_ShowTransferSumInput(playerid);
            return 1;
        }

        case DIALOG_BANK_TRANSFER_SUM:
        {
            if(!response) return 1;
            new amount = strval(inputtext);
            new targetid = gPlayer[playerid][bTransferTarget];
            if(targetid == INVALID_PLAYER_ID || !IsPlayerConnected(targetid))
            {
                SendClientMessage(playerid, COLOR_BANK_ERROR,
                    "[Банк] Получатель отключился.");
                return 1;
            }
            Bank_Transfer(playerid, targetid, amount);
            gPlayer[playerid][bTransferTarget] = INVALID_PLAYER_ID;
            return 1;
        }

        case DIALOG_BANK_HISTORY:
        {
            if(response) Bank_ShowMainMenu(playerid);
            return 1;
        }

        // ----- Меню кредитов ---------------------------------------------
        case DIALOG_CREDIT_MAIN:
        {
            if(!response) return 1;
            switch(listitem)
            {
                case 0: Bank_ShowCreditTake(playerid);
                case 1: Bank_ShowCreditPay(playerid);
                case 2: Bank_ShowCreditInfo(playerid);
            }
            return 1;
        }

        case DIALOG_CREDIT_TAKE:
        {
            if(!response) return 1;
            new amount = strval(inputtext);
            Bank_TakeCredit(playerid, amount);
            return 1;
        }

        case DIALOG_CREDIT_PAY:
        {
            if(!response) return 1;
            new amount = strval(inputtext);
            Bank_PayCredit(playerid, amount);
            return 1;
        }

        case DIALOG_CREDIT_INFO:
        {
            if(response) Bank_ShowCreditMenu(playerid);
            return 1;
        }

        // ----- Меню займов -----------------------------------------------
        case DIALOG_LOAN_MAIN:
        {
            if(!response) return 1;
            switch(listitem)
            {
                case 0: Bank_ShowLoanTake(playerid);
                case 1: Bank_ShowLoanPay(playerid);
                case 2: Bank_ShowLoanInfo(playerid);
            }
            return 1;
        }

        case DIALOG_LOAN_TAKE:
        {
            if(!response) return 1;
            new amount = strval(inputtext);
            Bank_TakeLoan(playerid, amount);
            return 1;
        }

        case DIALOG_LOAN_PAY:
        {
            if(!response) return 1;
            new amount = strval(inputtext);
            Bank_PayLoan(playerid, amount);
            return 1;
        }

        case DIALOG_LOAN_INFO:
        {
            if(response) Bank_ShowLoanMenu(playerid);
            return 1;
        }

        // ----- Админ-меню ------------------------------------------------
        case DIALOG_ADMIN_MAIN:
        {
            if(!response) return 1;
            if(!IsBankAdmin(playerid)) return 1;
            switch(listitem)
            {
                case 0: gPlayer[playerid][bAdminAction] = ADM_ACT_VIEW;
                case 1: gPlayer[playerid][bAdminAction] = ADM_ACT_GIVE_MONEY;
                case 2: gPlayer[playerid][bAdminAction] = ADM_ACT_TAKE_MONEY;
                case 3: gPlayer[playerid][bAdminAction] = ADM_ACT_GIVE_CREDIT;
                case 4: gPlayer[playerid][bAdminAction] = ADM_ACT_CLOSE_CREDIT;
                case 5: gPlayer[playerid][bAdminAction] = ADM_ACT_CLOSE_LOAN;
                case 6: gPlayer[playerid][bAdminAction] = ADM_ACT_CLEAR_HISTORY;
            }
            Bank_ShowAdminTargetInput(playerid);
            return 1;
        }

        case DIALOG_ADMIN_TARGET_ID:
        {
            if(!response) return 1;
            if(!IsBankAdmin(playerid)) return 1;
            new targetid = strval(inputtext);
            if(targetid < 0 || targetid >= GetMaxPlayers() || !IsPlayerConnected(targetid))
            {
                SendClientMessage(playerid, COLOR_BANK_ERROR,
                    "[Банк-Админ] Игрок не найден.");
                return 1;
            }
            if(!gPlayer[targetid][bLoaded])
            {
                SendClientMessage(playerid, COLOR_BANK_ERROR,
                    "[Банк-Админ] Счёт игрока ещё не загружен.");
                return 1;
            }
            gPlayer[playerid][bAdminTarget] = targetid;

            switch(gPlayer[playerid][bAdminAction])
            {
                case ADM_ACT_VIEW:
                    Bank_ShowAdminTargetView(playerid, targetid);

                case ADM_ACT_CLOSE_CREDIT:
                {
                    if(Bank_AdminCloseCredit(targetid))
                        SendClientMessage(playerid, COLOR_BANK_INFO,
                            "[Банк-Админ] Кредит игрока закрыт.");
                    else
                        SendClientMessage(playerid, COLOR_BANK_ERROR,
                            "[Банк-Админ] У игрока нет активного кредита.");
                }

                case ADM_ACT_CLOSE_LOAN:
                {
                    if(Bank_AdminCloseLoan(targetid))
                        SendClientMessage(playerid, COLOR_BANK_INFO,
                            "[Банк-Админ] Займ игрока закрыт.");
                    else
                        SendClientMessage(playerid, COLOR_BANK_ERROR,
                            "[Банк-Админ] У игрока нет активного займа.");
                }

                case ADM_ACT_CLEAR_HISTORY:
                {
                    Bank_DB_ClearHistory(gPlayer[targetid][bAccountID]);
                    SendClientMessage(playerid, COLOR_BANK_INFO,
                        "[Банк-Админ] История операций очищена.");
                }

                default:
                {
                    // Для GIVE_MONEY / TAKE_MONEY / GIVE_CREDIT нужна сумма
                    Bank_ShowAdminAmountInput(playerid);
                }
            }
            return 1;
        }

        case DIALOG_ADMIN_INPUT:
        {
            if(!response) return 1;
            if(!IsBankAdmin(playerid)) return 1;
            new amount = strval(inputtext);
            new targetid = gPlayer[playerid][bAdminTarget];
            if(targetid == INVALID_PLAYER_ID || !IsPlayerConnected(targetid))
            {
                SendClientMessage(playerid, COLOR_BANK_ERROR,
                    "[Банк-Админ] Игрок отключился.");
                return 1;
            }
            if(!Bank_IsValidAmount(amount))
            {
                SendClientMessage(playerid, COLOR_BANK_ERROR,
                    "[Банк-Админ] Некорректная сумма.");
                return 1;
            }

            switch(gPlayer[playerid][bAdminAction])
            {
                case ADM_ACT_GIVE_MONEY:
                {
                    gPlayer[targetid][bBalance] += amount;
                    Bank_DB_SavePlayer(targetid);
                    Bank_DB_AddHistory(targetid, HIST_ADMIN, amount,
                        "Админ начислил на счёт");
                    SendClientMessage(playerid, COLOR_BANK_INFO,
                        "[Банк-Админ] Сумма зачислена на счёт игрока.");
                    SendClientMessage(targetid, COLOR_BANK_INFO,
                        "[Банк] Администратор начислил вам деньги на счёт.");
                }

                case ADM_ACT_TAKE_MONEY:
                {
                    if(gPlayer[targetid][bBalance] < amount)
                    {
                        SendClientMessage(playerid, COLOR_BANK_ERROR,
                            "[Банк-Админ] У игрока недостаточно средств.");
                        return 1;
                    }
                    gPlayer[targetid][bBalance] -= amount;
                    Bank_DB_SavePlayer(targetid);
                    Bank_DB_AddHistory(targetid, HIST_ADMIN, amount,
                        "Админ снял со счёта");
                    SendClientMessage(playerid, COLOR_BANK_INFO,
                        "[Банк-Админ] Сумма списана со счёта игрока.");
                    SendClientMessage(targetid, COLOR_BANK_INFO,
                        "[Банк] Администратор снял деньги с вашего счёта.");
                }

                case ADM_ACT_GIVE_CREDIT:
                {
                    if(Bank_HasCredit(targetid))
                    {
                        SendClientMessage(playerid, COLOR_BANK_ERROR,
                            "[Банк-Админ] У игрока уже есть активный кредит.");
                        return 1;
                    }
                    if(amount < BANK_CREDIT_MIN || amount > BANK_CREDIT_MAX)
                    {
                        SendClientMessage(playerid, COLOR_BANK_ERROR,
                            "[Банк-Админ] Сумма вне допустимого диапазона.");
                        return 1;
                    }
                    new total = amount + (amount * BANK_CREDIT_PERCENT) / 100;
                    new daily = total / BANK_CREDIT_DAYS;
                    if(daily < 1) daily = 1;
                    gPlayer[targetid][bCreditAmount]  = amount;
                    gPlayer[targetid][bCreditDebt]    = total;
                    gPlayer[targetid][bCreditDaily]   = daily;
                    gPlayer[targetid][bCreditTaken]   = gettime();
                    gPlayer[targetid][bCreditNextPay] = gettime() + BANK_CREDIT_DAY_SECONDS;
                    gPlayer[targetid][bBalance]      += amount;
                    Bank_DB_SavePlayer(targetid);
                    Bank_DB_AddHistory(targetid, HIST_ADMIN, amount,
                        "Админ выдал кредит");
                    SendClientMessage(playerid, COLOR_BANK_INFO,
                        "[Банк-Админ] Кредит выдан.");
                    SendClientMessage(targetid, COLOR_BANK_INFO,
                        "[Банк] Администратор выдал вам кредит.");
                }
            }
            return 1;
        }
    }
    return 0;
}

/*
================================================================================
                            КОНЕЦ bank_system.pwn
================================================================================
Памятка по поведению:
- /bank, /atm — открывают главное меню банка (баланс, депозит, снятие,
  перевод, история, кредиты, займы)
- /credit, /loan — отдельные меню кредитов и займов
- /paycredit [сумма], /payloan [сумма] — быстрая оплата
- /bankadmin — админ-меню (только для тех, у кого IsBankAdmin == true)
Все суммы автоматически проверяются на корректность, отрицательные значения
и лимиты. Cooldown между командами защищает от спама. Каждая операция
записывается в bank_history и видна в диалоге «История операций».
================================================================================
*/

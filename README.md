# aiopus — Руководство по скриптингу Pawn

## Содержание

- [Введение](#введение)
- [Установка и настройка среды](#установка-и-настройка-среды)
- [Основы языка Pawn](#основы-языка-pawn)
  - [Структура скрипта](#структура-скрипта)
  - [Переменные и типы данных](#переменные-и-типы-данных)
  - [Операторы](#операторы)
  - [Условные конструкции](#условные-конструкции)
  - [Циклы](#циклы)
  - [Массивы и строки](#массивы-и-строки)
  - [Функции](#функции)
  - [Директивы препроцессора](#директивы-препроцессора)
- [SA-MP скриптинг](#sa-mp-скриптинг)
  - [Основные колбэки](#основные-колбэки)
  - [Работа с игроками](#работа-с-игроками)
  - [Работа с транспортом](#работа-с-транспортом)
  - [Диалоги](#диалоги)
  - [Таймеры](#таймеры)
  - [Текстдравы (TextDraw)](#текстдравы-textdraw)
  - [3D-тексты](#3d-тексты)
  - [Работа с файлами](#работа-с-файлами)
- [open.mp — современная альтернатива](#openmp--современная-альтернатива)
- [Полезные плагины и инклуды](#полезные-плагины-и-инклуды)
- [Примеры готовых систем](#примеры-готовых-систем)
  - [Система регистрации и авторизации](#система-регистрации-и-авторизации)
  - [Система команд (ZCMD)](#система-команд-zcmd)
  - [Система дома](#система-дома)
- [Советы и лучшие практики](#советы-и-лучшие-практики)
- [Полезные ресурсы](#полезные-ресурсы)

---

## Введение

**Pawn** — это простой скриптовый язык без типов (typeless), разработанный для встраивания в другие приложения. В контексте SA-MP (San Andreas Multiplayer) и open.mp Pawn используется для создания серверных скриптов (геймодов, фильтрскриптов), управляющих игровой логикой.

Основные особенности:
- C-подобный синтаксис
- Простая структура без ООП
- Компилируется в байт-код (`.amx`)
- Расширяется через плагины и инклуды

---

## Установка и настройка среды

### Необходимые компоненты

1. **SA-MP сервер** — скачать с [sa-mp.mp](https://sa-mp.mp/) или использовать [open.mp](https://open.mp/)
2. **Компилятор Pawn** (`pawncc`) — идёт в комплекте с сервером
3. **Редактор кода** — рекомендуется:
   - [Pawno](https://sa-mp.mp/) — стандартный редактор (идёт с сервером)
   - [VS Code](https://code.visualstudio.com/) + расширение [Pawn Tools](https://marketplace.visualstudio.com/items?itemName=southclaws.vscode-pawn)
   - [Sublime Text](https://www.sublimetext.com/) + Pawn-синтаксис

### Структура сервера

```
server/
├── gamemodes/          # Геймоды (.pwn / .amx)
├── filterscripts/      # Фильтрскрипты
├── include/            # Подключаемые файлы (.inc)
├── plugins/            # Плагины (.so / .dll)
├── scriptfiles/        # Файлы данных (БД, логи, конфиги)
├── npcmodes/           # NPC-скрипты
├── samp-server         # Исполняемый файл сервера (Linux)
├── samp-server.exe     # Исполняемый файл сервера (Windows)
└── server.cfg          # Конфигурация сервера
```

### Компиляция

```bash
# Linux
./pawncc gamemodes/mygamemode.pwn -o gamemodes/mygamemode.amx

# Windows
pawncc.exe gamemodes\mygamemode.pwn -o gamemodes\mygamemode.amx
```

### Настройка server.cfg

```ini
gamemode0 mygamemode
filterscripts
plugins
port 7777
hostname My Server
maxplayers 50
language Russian
rcon_password changeme
```

---

## Основы языка Pawn

### Структура скрипта

Каждый геймод начинается с подключения стандартной библиотеки и основного колбэка:

```pawn
#include <a_samp>

main()
{
    print("Геймод загружен!");
}

public OnGameModeInit()
{
    SetGameModeText("My Gamemode");
    AddPlayerClass(0, 0.0, 0.0, 5.0, 0.0, 0, 0, 0, 0, 0, 0);
    return 1;
}
```

### Переменные и типы данных

Pawn — язык без явных типов. Все переменные по умолчанию являются целочисленными (32-bit integer). Для дробных чисел используется тег `Float:`.

```pawn
// Целые числа
new playerScore = 0;
new maxHealth = 100;

// Дробные числа (Float)
new Float:posX = 150.5;
new Float:posY = -200.3;
new Float:posZ = 10.0;

// Строки (массивы символов)
new playerName[MAX_PLAYER_NAME];
new message[128] = "Привет, мир!";

// Булевы значения (через тег bool:)
new bool:isLoggedIn = false;
new bool:isAdmin = true;

// Константы
#define MAX_HOUSES 100
#define COLOR_RED 0xFF0000FF
const MAX_VEHICLES = 2000;

// Перечисления (enum)
enum PlayerInfo
{
    pLevel,
    pMoney,
    pScore,
    Float:pHealth,
    pName[MAX_PLAYER_NAME],
    bool:pAdmin
};

new PlayerData[MAX_PLAYERS][PlayerInfo];
```

### Операторы

```pawn
// Арифметические
new a = 10 + 5;    // 15
new b = 10 - 3;    // 7
new c = 4 * 3;     // 12
new d = 10 / 3;    // 3
new e = 10 % 3;    // 1

// Сравнения
// ==  !=  <  >  <=  >=

// Логические
// &&  ||  !

// Побитовые
// &  |  ^  ~  <<  >>

// Присваивание
// =  +=  -=  *=  /=

// Инкремент / декремент
a++;
b--;
```

### Условные конструкции

```pawn
// if / else if / else
if (score > 100)
{
    SendClientMessage(playerid, COLOR_GREEN, "Отличный результат!");
}
else if (score > 50)
{
    SendClientMessage(playerid, COLOR_YELLOW, "Хороший результат!");
}
else
{
    SendClientMessage(playerid, COLOR_RED, "Попробуй ещё раз.");
}

// switch / case
switch (dialogid)
{
    case 0:
    {
        // Обработка диалога 0
    }
    case 1:
    {
        // Обработка диалога 1
    }
    default:
    {
        // По умолчанию
    }
}

// Тернарный оператор
new result = (a > b) ? a : b;
```

### Циклы

```pawn
// for
for (new i = 0; i < MAX_PLAYERS; i++)
{
    if (IsPlayerConnected(i))
    {
        SendClientMessage(i, -1, "Сообщение всем!");
    }
}

// while
new attempts = 0;
while (attempts < 3)
{
    // ...
    attempts++;
}

// do-while
do
{
    // Выполнится хотя бы один раз
} while (condition);

// foreach (требуется инклуд foreach или y_iterate)
foreach (new i : Player)
{
    SendClientMessage(i, -1, "Сообщение всем (оптимизировано)!");
}
```

### Массивы и строки

```pawn
// Одномерный массив
new weapons[13];
weapons[0] = 24; // Desert Eagle

// Двумерный массив
new spawnPositions[3][4] =
{
    {1500.0, -1200.0, 15.0, 90.0},
    {2000.0, -1500.0, 25.0, 180.0},
    {800.0,  -900.0,  10.0, 0.0}
};

// Работа со строками
new str[256];

// Форматирование строк
format(str, sizeof(str), "Игрок %s набрал %d очков", playerName, score);

// Конкатенация
strcat(str, " — поздравляем!");

// Сравнение строк
if (strcmp(inputText, "hello", true) == 0) // true = игнорировать регистр
{
    // Строки совпадают
}

// Длина строки
new len = strlen(str);

// Поиск подстроки
new pos = strfind(str, "очков");

// Числа <-> строки
new number = strval("123");       // строка -> число
valstr(str, 456);                 // число -> строка
```

### Функции

```pawn
// Обычная функция
stock GetPlayerFullName(playerid, output[], size = sizeof(output))
{
    GetPlayerName(playerid, output, size);
    return 1;
}

// Функция с возвратом Float
stock Float:GetDistanceBetweenPlayers(player1, player2)
{
    new Float:x1, Float:y1, Float:z1;
    new Float:x2, Float:y2, Float:z2;
    GetPlayerPos(player1, x1, y1, z1);
    GetPlayerPos(player2, x2, y2, z2);
    return floatsqroot(
        floatpower(x1 - x2, 2.0) +
        floatpower(y1 - y2, 2.0) +
        floatpower(z1 - z2, 2.0)
    );
}

// Public-функция (для таймеров, колбэков)
forward MyTimer(playerid);
public MyTimer(playerid)
{
    SendClientMessage(playerid, -1, "Таймер сработал!");
}

// stock — функция не компилируется, если не используется
// forward — объявление public-функции
```

### Директивы препроцессора

```pawn
// Подключение файлов
#include <a_samp>
#include <zcmd>
#include "../include/myutils.inc"

// Определения (макросы)
#define MAX_HOUSES      100
#define COLOR_WHITE     0xFFFFFFFF
#define SCM             SendClientMessage

// Макрос с параметрами
#define SetPlayerFullHealth(%0) SetPlayerHealth(%0, 100.0)

// Условная компиляция
#if defined USE_MYSQL
    #include <a_mysql>
#else
    #include <a_samp>
#endif

// Прагмы
#pragma tabsize 0   // Убрать предупреждения о табуляции
```

---

## SA-MP скриптинг

### Основные колбэки

Колбэки (callbacks) — функции, автоматически вызываемые сервером при определённых событиях:

```pawn
// Инициализация геймода
public OnGameModeInit()
{
    SetGameModeText("RPG Gamemode");
    UsePlayerPedAnims();            // Плавная анимация ходьбы
    DisableInteriorEnterExits();    // Отключить стандартные входы
    EnableStuntBonusForAll(0);      // Отключить бонусы за трюки
    ShowPlayerMarkers(1);           // Показать маркеры игроков
    ShowNameTags(1);                // Показать имена над головой
    SetNameTagDrawDistance(40.0);
    return 1;
}

// Выключение геймода
public OnGameModeExit()
{
    print("Геймод выключен.");
    return 1;
}

// Подключение игрока
public OnPlayerConnect(playerid)
{
    new name[MAX_PLAYER_NAME], str[128];
    GetPlayerName(playerid, name, sizeof(name));
    format(str, sizeof(str), "%s подключился к серверу.", name);
    SendClientMessageToAll(COLOR_GREEN, str);
    return 1;
}

// Отключение игрока
public OnPlayerDisconnect(playerid, reason)
{
    new name[MAX_PLAYER_NAME], str[128], reasonMsg[20];
    GetPlayerName(playerid, name, sizeof(name));

    switch (reason)
    {
        case 0: reasonMsg = "Таймаут";
        case 1: reasonMsg = "Выход";
        case 2: reasonMsg = "Кик/Бан";
    }

    format(str, sizeof(str), "%s вышел с сервера. (%s)", name, reasonMsg);
    SendClientMessageToAll(COLOR_RED, str);
    return 1;
}

// Спавн игрока
public OnPlayerSpawn(playerid)
{
    SetPlayerHealth(playerid, 100.0);
    SetPlayerArmour(playerid, 0.0);
    return 1;
}

// Смерть игрока
public OnPlayerDeath(playerid, killerid, reason)
{
    if (killerid != INVALID_PLAYER_ID)
    {
        // Игрок убит другим игроком
        GivePlayerMoney(killerid, 500);
        SetPlayerScore(killerid, GetPlayerScore(killerid) + 1);
    }
    return 1;
}

// Игрок вводит текст в чат
public OnPlayerText(playerid, text[])
{
    new name[MAX_PLAYER_NAME], str[256];
    GetPlayerName(playerid, name, sizeof(name));
    format(str, sizeof(str), "%s: %s", name, text);
    SendClientMessageToAll(-1, str);
    return 0; // return 0 — отменяет стандартный чат
}

// Ввод команды (без ZCMD)
public OnPlayerCommandText(playerid, cmdtext[])
{
    if (strcmp(cmdtext, "/help", true) == 0)
    {
        SendClientMessage(playerid, -1, "Список команд: /help, /stats, /tp");
        return 1;
    }
    return 0; // Команда не найдена
}
```

### Работа с игроками

```pawn
// Позиция
new Float:x, Float:y, Float:z;
GetPlayerPos(playerid, x, y, z);
SetPlayerPos(playerid, 1500.0, -1200.0, 15.0);

// Здоровье и броня
SetPlayerHealth(playerid, 100.0);
SetPlayerArmour(playerid, 50.0);

new Float:health;
GetPlayerHealth(playerid, health);

// Оружие
GivePlayerWeapon(playerid, 24, 100);  // Desert Eagle, 100 патронов
ResetPlayerWeapons(playerid);

// Деньги
GivePlayerMoney(playerid, 5000);
ResetPlayerMoney(playerid);
new money = GetPlayerMoney(playerid);

// Скин
SetPlayerSkin(playerid, 285);

// Виртуальный мир и интерьер
SetPlayerVirtualWorld(playerid, 1);
SetPlayerInterior(playerid, 5);

// Заморозить / разморозить
TogglePlayerControllable(playerid, 0);  // Заморозить
TogglePlayerControllable(playerid, 1);  // Разморозить

// Телепортация к другому игроку
stock TeleportToPlayer(playerid, targetid)
{
    new Float:tx, Float:ty, Float:tz;
    GetPlayerPos(targetid, tx, ty, tz);
    SetPlayerPos(playerid, tx + 1.0, ty, tz);
    SetPlayerInterior(playerid, GetPlayerInterior(targetid));
    SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(targetid));
}
```

### Работа с транспортом

```pawn
// Создание транспорта
new vehicleid = CreateVehicle(
    411,        // Infernus (ID модели)
    1500.0,     // X
    -1200.0,    // Y
    15.0,       // Z
    90.0,       // Угол поворота
    1,          // Цвет 1
    1,          // Цвет 2
    -1          // Время респавна (-1 = не респавнится)
);

// Посадить игрока в транспорт
PutPlayerInVehicle(playerid, vehicleid, 0); // 0 = водитель

// Колбэки транспорта
public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
    new str[64];
    format(str, sizeof(str), "Вы садитесь в транспорт ID: %d", vehicleid);
    SendClientMessage(playerid, -1, str);
    return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
    SendClientMessage(playerid, -1, "Вы вышли из транспорта.");
    return 1;
}

// Модификация транспорта
AddVehicleComponent(vehicleid, 1010); // Нитро
ChangeVehicleColor(vehicleid, 3, 3);
SetVehicleHealth(vehicleid, 1000.0);
RepairVehicle(vehicleid);
SetVehicleNumberPlate(vehicleid, "SAMP");
```

### Диалоги

SA-MP поддерживает несколько типов диалогов:

```pawn
#define DIALOG_LOGIN    0
#define DIALOG_REGISTER 1
#define DIALOG_SHOP     2
#define DIALOG_INFO     3

// DIALOG_STYLE_MSGBOX — простое сообщение
ShowPlayerDialog(playerid, DIALOG_INFO, DIALOG_STYLE_MSGBOX,
    "Информация",
    "Добро пожаловать на наш сервер!\nПриятной игры!",
    "OK", "");

// DIALOG_STYLE_INPUT — ввод текста
ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_INPUT,
    "Авторизация",
    "Введите ваш пароль:",
    "Войти", "Выход");

// DIALOG_STYLE_PASSWORD — ввод пароля (текст скрыт)
ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD,
    "Регистрация",
    "Придумайте пароль:",
    "Зарегистрироваться", "Выход");

// DIALOG_STYLE_LIST — список
ShowPlayerDialog(playerid, DIALOG_SHOP, DIALOG_STYLE_LIST,
    "Магазин оружия",
    "Desert Eagle — $500\nShotgun — $300\nMP5 — $400\nM4 — $800\nSniper — $1000",
    "Купить", "Отмена");

// DIALOG_STYLE_TABLIST_HEADERS — список с заголовками
ShowPlayerDialog(playerid, DIALOG_SHOP, DIALOG_STYLE_TABLIST_HEADERS,
    "Магазин",
    "Предмет\tЦена\tНаличие\n\
     Desert Eagle\t$500\tЕсть\n\
     Shotgun\t$300\tЕсть\n\
     M4\t$800\tНет",
    "Купить", "Отмена");

// Обработка ответа
public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch (dialogid)
    {
        case DIALOG_LOGIN:
        {
            if (!response) return Kick(playerid); // Нажал "Выход"
            if (strlen(inputtext) < 3)
            {
                ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_INPUT,
                    "Авторизация", "Неверный пароль! Попробуйте снова:",
                    "Войти", "Выход");
                return 1;
            }
            // Проверка пароля ...
        }
        case DIALOG_SHOP:
        {
            if (!response) return 1; // Нажал "Отмена"
            switch (listitem)
            {
                case 0: // Desert Eagle
                {
                    if (GetPlayerMoney(playerid) >= 500)
                    {
                        GivePlayerMoney(playerid, -500);
                        GivePlayerWeapon(playerid, 24, 50);
                    }
                }
                case 1: // Shotgun
                {
                    if (GetPlayerMoney(playerid) >= 300)
                    {
                        GivePlayerMoney(playerid, -300);
                        GivePlayerWeapon(playerid, 25, 30);
                    }
                }
            }
        }
    }
    return 1;
}
```

### Таймеры

```pawn
// Одноразовый таймер (выполнится через 5 секунд)
SetTimerEx("WelcomeMessage", 5000, false, "i", playerid);

forward WelcomeMessage(playerid);
public WelcomeMessage(playerid)
{
    SendClientMessage(playerid, COLOR_GREEN, "Добро пожаловать на сервер!");
}

// Повторяющийся таймер (каждые 60 секунд)
new payTimer = SetTimer("PayDay", 60000, true);

forward PayDay();
public PayDay()
{
    foreach (new i : Player)
    {
        GivePlayerMoney(i, 1000);
        SendClientMessage(i, COLOR_GREEN, "Вы получили зарплату: $1000");
    }
}

// Остановка таймера
KillTimer(payTimer);

// Спецификаторы формата для SetTimerEx:
// "i" — integer
// "f" — float
// "s" — string
// Пример с несколькими аргументами:
SetTimerEx("HealPlayer", 3000, false, "if", playerid, 50.0);

forward HealPlayer(playerid, Float:amount);
public HealPlayer(playerid, Float:amount)
{
    new Float:hp;
    GetPlayerHealth(playerid, hp);
    SetPlayerHealth(playerid, hp + amount);
}
```

### Текстдравы (TextDraw)

TextDraw — элементы HUD, отображаемые поверх игрового экрана:

```pawn
new Text:serverInfo;
new PlayerText:playerHUD[MAX_PLAYERS];

public OnGameModeInit()
{
    // Глобальный TextDraw (виден всем)
    serverInfo = TextDrawCreate(320.0, 5.0, "My Server | Players: 0");
    TextDrawFont(serverInfo, 2);
    TextDrawLetterSize(serverInfo, 0.3, 1.2);
    TextDrawColor(serverInfo, 0xFFFFFFFF);
    TextDrawSetOutline(serverInfo, 1);
    TextDrawSetShadow(serverInfo, 0);
    TextDrawAlignment(serverInfo, 2); // По центру
    TextDrawBackgroundColor(serverInfo, 0x000000AA);
    TextDrawSetProportional(serverInfo, 1);
    return 1;
}

public OnPlayerConnect(playerid)
{
    // Показать глобальный TextDraw
    TextDrawShowForPlayer(playerid, serverInfo);

    // Создать персональный TextDraw
    playerHUD[playerid] = CreatePlayerTextDraw(playerid, 550.0, 400.0, "HP: 100");
    PlayerTextDrawFont(playerid, playerHUD[playerid], 2);
    PlayerTextDrawLetterSize(playerid, playerHUD[playerid], 0.25, 1.0);
    PlayerTextDrawColor(playerid, playerHUD[playerid], 0xFF0000FF);
    PlayerTextDrawShow(playerid, playerHUD[playerid]);
    return 1;
}

// Обновление TextDraw
stock UpdatePlayerHUD(playerid)
{
    new Float:hp, str[32];
    GetPlayerHealth(playerid, hp);
    format(str, sizeof(str), "HP: %.0f", hp);
    PlayerTextDrawSetString(playerid, playerHUD[playerid], str);
}
```

### 3D-тексты

```pawn
// Глобальная 3D-метка
new Text3D:houseLabel;
houseLabel = Create3DTextLabel(
    "Дом на продажу\nЦена: $50000",  // Текст
    COLOR_GREEN,                      // Цвет
    1500.0, -1200.0, 15.0,           // Позиция
    20.0,                             // Дистанция отрисовки
    0,                                // Виртуальный мир
    0                                 // Тест LOS (line of sight)
);

// 3D-метка привязанная к игроку
new Text3D:playerLabel[MAX_PLAYERS];

public OnPlayerSpawn(playerid)
{
    new name[MAX_PLAYER_NAME], str[64];
    GetPlayerName(playerid, name, sizeof(name));
    format(str, sizeof(str), "%s\n{FF0000}Уровень: %d", name, PlayerData[playerid][pLevel]);

    playerLabel[playerid] = Create3DTextLabel(str, COLOR_WHITE, 0.0, 0.0, 0.0, 20.0, 0, 0);
    Attach3DTextLabelToPlayer(playerLabel[playerid], playerid, 0.0, 0.0, 0.3);
    return 1;
}
```

### Работа с файлами

```pawn
// === Встроенные функции (fopen / fwrite / fread) ===

// Запись в файл
stock SavePlayerData(playerid)
{
    new name[MAX_PLAYER_NAME], filename[64], str[256];
    GetPlayerName(playerid, name, sizeof(name));
    format(filename, sizeof(filename), "players/%s.ini", name);

    new File:file = fopen(filename, io_write);
    if (file)
    {
        format(str, sizeof(str), "Level=%d\n", PlayerData[playerid][pLevel]);
        fwrite(file, str);
        format(str, sizeof(str), "Money=%d\n", PlayerData[playerid][pMoney]);
        fwrite(file, str);
        format(str, sizeof(str), "Score=%d\n", PlayerData[playerid][pScore]);
        fwrite(file, str);
        fclose(file);
    }
}

// Чтение из файла
stock LoadPlayerData(playerid)
{
    new name[MAX_PLAYER_NAME], filename[64], str[256];
    GetPlayerName(playerid, name, sizeof(name));
    format(filename, sizeof(filename), "players/%s.ini", name);

    if (!fexist(filename)) return 0;

    new File:file = fopen(filename, io_read);
    if (file)
    {
        new key[32], val[128];
        while (fread(file, str))
        {
            strmid(key, str, 0, strfind(str, "="));
            strmid(val, str, strfind(str, "=") + 1, strlen(str) - 1);

            if (!strcmp(key, "Level")) PlayerData[playerid][pLevel] = strval(val);
            if (!strcmp(key, "Money")) PlayerData[playerid][pMoney] = strval(val);
            if (!strcmp(key, "Score")) PlayerData[playerid][pScore] = strval(val);
        }
        fclose(file);
    }
    return 1;
}

// === Проверка существования файла ===
if (fexist("players/admin.ini"))
{
    print("Файл найден!");
}
```

---

## open.mp — современная альтернатива

[open.mp](https://open.mp/) — это современная переработка SA-MP сервера с обратной совместимостью. Ключевые преимущества:

- Полная совместимость с существующими SA-MP скриптами
- Улучшенная производительность и стабильность
- Новые функции и возможности
- Активная разработка и сообщество
- Встроенная поддержка `foreach`, `PawnPlus` и других расширений
- Увеличенные лимиты (больше транспорта, объектов, текстдравов)

### Миграция с SA-MP на open.mp

```pawn
// Замените:
#include <a_samp>
// На:
#include <open.mp>

// Большинство скриптов работают без изменений.
// Новые функции open.mp доступны через инклуд <open.mp>.
```

---

## Полезные плагины и инклуды

| Название | Описание | Ссылка |
|----------|----------|--------|
| **MySQL (R41+)** | Работа с базой данных MySQL | [GitHub](https://github.com/pBlueG/SA-MP-MySQL) |
| **Streamer** | Стриминг объектов, пикапов, чекпоинтов | [GitHub](https://github.com/samp-incognito/samp-streamer-plugin) |
| **sscanf2** | Парсинг строк и аргументов команд | [GitHub](https://github.com/Y-Less/sscanf) |
| **ZCMD** | Быстрый обработчик команд | [GitHub](https://github.com/ZeeX/zcmd) |
| **foreach** | Оптимизированные итераторы | Включен в YSI |
| **YSI** | Библиотека утилит (y_hooks, y_iterate и др.) | [GitHub](https://github.com/pawn-lang/YSI-Includes) |
| **Pawn.CMD** | Самый быстрый обработчик команд | [GitHub](https://github.com/katursis/Pawn.CMD) |
| **Pawn.RakNet** | Работа с RakNet-пакетами | [GitHub](https://github.com/katursis/Pawn.RakNet) |
| **CrashDetect** | Обнаружение крэшей в скриптах | [GitHub](https://github.com/Zeex/samp-plugin-crashdetect) |
| **MapAndreas** | Получение высоты карты | [GitHub](https://github.com/philip1337/samp-plugin-mapandreas) |
| **ColAndreas** | Физика и коллизии | [GitHub](https://github.com/Pottus/ColAndreas) |
| **Discord Connector** | Интеграция с Discord | [GitHub](https://github.com/maddinat0r/samp-discord-connector) |

---

## Примеры готовых систем

### Система регистрации и авторизации

```pawn
#include <a_samp>
#include <a_mysql>

#define MYSQL_HOST "127.0.0.1"
#define MYSQL_USER "root"
#define MYSQL_PASS "password"
#define MYSQL_DB   "samp_server"

#define DIALOG_REG  0
#define DIALOG_LOG  1

new MySQL:dbHandle;

enum pInfo
{
    pID,
    pPassword[65],
    pLevel,
    pMoney,
    pKills,
    pDeaths,
    bool:pLoggedIn
};
new PlayerData[MAX_PLAYERS][pInfo];

public OnGameModeInit()
{
    dbHandle = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASS, MYSQL_DB);
    if (dbHandle == MYSQL_INVALID_HANDLE || mysql_errno(dbHandle) != 0)
    {
        print("[MySQL] Не удалось подключиться к базе данных!");
        SendRconCommand("exit");
        return 1;
    }
    print("[MySQL] Подключение установлено.");

    mysql_tquery(dbHandle, "\
        CREATE TABLE IF NOT EXISTS `players` (\
            `id` INT AUTO_INCREMENT PRIMARY KEY,\
            `name` VARCHAR(24) NOT NULL UNIQUE,\
            `password` VARCHAR(64) NOT NULL,\
            `level` INT DEFAULT 0,\
            `money` INT DEFAULT 0,\
            `kills` INT DEFAULT 0,\
            `deaths` INT DEFAULT 0\
        )", "", "");
    return 1;
}

public OnPlayerConnect(playerid)
{
    new name[MAX_PLAYER_NAME], query[256];
    GetPlayerName(playerid, name, sizeof(name));
    mysql_format(dbHandle, query, sizeof(query),
        "SELECT * FROM `players` WHERE `name` = '%e' LIMIT 1", name);
    mysql_tquery(dbHandle, query, "OnPlayerDataLoaded", "i", playerid);
    return 1;
}

forward OnPlayerDataLoaded(playerid);
public OnPlayerDataLoaded(playerid)
{
    if (cache_num_rows() > 0)
    {
        // Аккаунт найден — предложить вход
        cache_get_value_name_int(0, "id", PlayerData[playerid][pID]);
        cache_get_value_name(0, "password", PlayerData[playerid][pPassword], 65);
        cache_get_value_name_int(0, "level", PlayerData[playerid][pLevel]);
        cache_get_value_name_int(0, "money", PlayerData[playerid][pMoney]);
        cache_get_value_name_int(0, "kills", PlayerData[playerid][pKills]);
        cache_get_value_name_int(0, "deaths", PlayerData[playerid][pDeaths]);

        ShowPlayerDialog(playerid, DIALOG_LOG, DIALOG_STYLE_PASSWORD,
            "Авторизация", "Добро пожаловать! Введите пароль:",
            "Войти", "Выход");
    }
    else
    {
        // Аккаунт не найден — предложить регистрацию
        ShowPlayerDialog(playerid, DIALOG_REG, DIALOG_STYLE_PASSWORD,
            "Регистрация", "Вы здесь впервые! Придумайте пароль:",
            "Зарегистрироваться", "Выход");
    }
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if (dialogid == DIALOG_REG)
    {
        if (!response) return Kick(playerid);
        if (strlen(inputtext) < 4)
        {
            ShowPlayerDialog(playerid, DIALOG_REG, DIALOG_STYLE_PASSWORD,
                "Регистрация", "Пароль слишком короткий (минимум 4 символа):",
                "Зарегистрироваться", "Выход");
            return 1;
        }

        new name[MAX_PLAYER_NAME], query[512], hash[65];
        GetPlayerName(playerid, name, sizeof(name));
        SHA256_PassHash(inputtext, "", hash, sizeof(hash));

        mysql_format(dbHandle, query, sizeof(query),
            "INSERT INTO `players` (`name`, `password`) VALUES ('%e', '%s')",
            name, hash);
        mysql_tquery(dbHandle, query, "OnPlayerRegistered", "i", playerid);
    }
    else if (dialogid == DIALOG_LOG)
    {
        if (!response) return Kick(playerid);

        new hash[65];
        SHA256_PassHash(inputtext, "", hash, sizeof(hash));

        if (strcmp(hash, PlayerData[playerid][pPassword]) == 0)
        {
            PlayerData[playerid][pLoggedIn] = true;
            GivePlayerMoney(playerid, PlayerData[playerid][pMoney]);
            SetPlayerScore(playerid, PlayerData[playerid][pLevel]);
            SendClientMessage(playerid, COLOR_GREEN, "Вы успешно авторизовались!");
        }
        else
        {
            ShowPlayerDialog(playerid, DIALOG_LOG, DIALOG_STYLE_PASSWORD,
                "Авторизация", "Неверный пароль! Попробуйте снова:",
                "Войти", "Выход");
        }
    }
    return 1;
}

forward OnPlayerRegistered(playerid);
public OnPlayerRegistered(playerid)
{
    PlayerData[playerid][pID] = cache_insert_id();
    PlayerData[playerid][pLoggedIn] = true;
    SendClientMessage(playerid, COLOR_GREEN, "Вы успешно зарегистрировались!");
}

public OnPlayerDisconnect(playerid, reason)
{
    if (PlayerData[playerid][pLoggedIn])
    {
        new query[256];
        mysql_format(dbHandle, query, sizeof(query),
            "UPDATE `players` SET `money` = %d, `level` = %d, `kills` = %d, \
             `deaths` = %d WHERE `id` = %d",
            GetPlayerMoney(playerid), GetPlayerScore(playerid),
            PlayerData[playerid][pKills], PlayerData[playerid][pDeaths],
            PlayerData[playerid][pID]);
        mysql_tquery(dbHandle, query);
    }

    // Сброс данных
    PlayerData[playerid][pLoggedIn] = false;
    PlayerData[playerid][pID] = 0;
    PlayerData[playerid][pLevel] = 0;
    PlayerData[playerid][pMoney] = 0;
    PlayerData[playerid][pKills] = 0;
    PlayerData[playerid][pDeaths] = 0;
    return 1;
}
```

### Система команд (ZCMD)

```pawn
#include <zcmd>
#include <sscanf2>

// /heal [playerid]
CMD:heal(playerid, params[])
{
    if (!IsPlayerAdmin(playerid))
        return SendClientMessage(playerid, COLOR_RED, "У вас нет доступа!");

    new targetid;
    if (sscanf(params, "u", targetid))
        return SendClientMessage(playerid, COLOR_GREY, "Используйте: /heal [ID игрока]");

    if (!IsPlayerConnected(targetid))
        return SendClientMessage(playerid, COLOR_RED, "Игрок не в сети!");

    SetPlayerHealth(targetid, 100.0);
    SendClientMessage(targetid, COLOR_GREEN, "Администратор восстановил вам здоровье.");
    SendClientMessage(playerid, COLOR_GREEN, "Вы восстановили здоровье игроку.");
    return 1;
}

// /tp [playerid]
CMD:tp(playerid, params[])
{
    new targetid;
    if (sscanf(params, "u", targetid))
        return SendClientMessage(playerid, COLOR_GREY, "Используйте: /tp [ID игрока]");

    if (!IsPlayerConnected(targetid))
        return SendClientMessage(playerid, COLOR_RED, "Игрок не в сети!");

    new Float:x, Float:y, Float:z;
    GetPlayerPos(targetid, x, y, z);
    SetPlayerPos(playerid, x + 1.0, y, z);
    SetPlayerInterior(playerid, GetPlayerInterior(targetid));
    SetPlayerVirtualWorld(playerid, GetPlayerVirtualWorld(targetid));
    return 1;
}

// /v [modelid] — создать транспорт
CMD:v(playerid, params[])
{
    if (!IsPlayerAdmin(playerid))
        return SendClientMessage(playerid, COLOR_RED, "У вас нет доступа!");

    new modelid;
    if (sscanf(params, "d", modelid))
        return SendClientMessage(playerid, COLOR_GREY, "Используйте: /v [ID модели]");

    if (modelid < 400 || modelid > 611)
        return SendClientMessage(playerid, COLOR_RED, "Неверный ID модели (400-611).");

    new Float:x, Float:y, Float:z, Float:angle;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, angle);

    new vid = CreateVehicle(modelid, x + 3.0, y, z, angle, -1, -1, -1);
    PutPlayerInVehicle(playerid, vid, 0);
    return 1;
}

// /pm [playerid] [message]
CMD:pm(playerid, params[])
{
    new targetid, message[128];
    if (sscanf(params, "us[128]", targetid, message))
        return SendClientMessage(playerid, COLOR_GREY, "Используйте: /pm [ID] [сообщение]");

    if (!IsPlayerConnected(targetid))
        return SendClientMessage(playerid, COLOR_RED, "Игрок не в сети!");

    new senderName[MAX_PLAYER_NAME], str[256];
    GetPlayerName(playerid, senderName, sizeof(senderName));

    format(str, sizeof(str), "[ЛС от %s (%d)]: %s", senderName, playerid, message);
    SendClientMessage(targetid, COLOR_YELLOW, str);

    format(str, sizeof(str), "[ЛС для %d]: %s", targetid, message);
    SendClientMessage(playerid, COLOR_YELLOW, str);
    return 1;
}
```

### Система дома

```pawn
#define MAX_HOUSES 200

enum HouseInfo
{
    hID,
    Float:hEnterX,
    Float:hEnterY,
    Float:hEnterZ,
    Float:hExitX,
    Float:hExitY,
    Float:hExitZ,
    hInterior,
    hPrice,
    hOwner[MAX_PLAYER_NAME],
    bool:hOwned,
    hPickup,
    Text3D:hLabel
};

new HouseData[MAX_HOUSES][HouseInfo];
new TotalHouses = 0;

stock CreateHouse(Float:enterX, Float:enterY, Float:enterZ,
                  Float:exitX, Float:exitY, Float:exitZ,
                  interior, price)
{
    new id = TotalHouses;
    if (id >= MAX_HOUSES) return -1;

    HouseData[id][hEnterX] = enterX;
    HouseData[id][hEnterY] = enterY;
    HouseData[id][hEnterZ] = enterZ;
    HouseData[id][hExitX] = exitX;
    HouseData[id][hExitY] = exitY;
    HouseData[id][hExitZ] = exitZ;
    HouseData[id][hInterior] = interior;
    HouseData[id][hPrice] = price;
    HouseData[id][hOwned] = false;
    HouseData[id][hOwner] = '\0';

    new str[256];
    format(str, sizeof(str),
        "{00FF00}Дом #%d\n{FFFFFF}Цена: {00FF00}$%d\n{FFFFFF}/buyhouse — купить",
        id, price);

    HouseData[id][hLabel] = Create3DTextLabel(str, 0xFFFFFFFF, enterX, enterY, enterZ + 0.5, 15.0, 0, 0);
    HouseData[id][hPickup] = CreatePickup(1273, 1, enterX, enterY, enterZ, 0);

    TotalHouses++;
    return id;
}

CMD:buyhouse(playerid, params[])
{
    for (new i = 0; i < TotalHouses; i++)
    {
        if (IsPlayerInRangeOfPoint(playerid, 2.0,
            HouseData[i][hEnterX], HouseData[i][hEnterY], HouseData[i][hEnterZ]))
        {
            if (HouseData[i][hOwned])
                return SendClientMessage(playerid, COLOR_RED, "Этот дом уже куплен.");

            if (GetPlayerMoney(playerid) < HouseData[i][hPrice])
                return SendClientMessage(playerid, COLOR_RED, "У вас недостаточно денег.");

            new name[MAX_PLAYER_NAME];
            GetPlayerName(playerid, name, sizeof(name));

            GivePlayerMoney(playerid, -HouseData[i][hPrice]);
            HouseData[i][hOwned] = true;
            format(HouseData[i][hOwner], MAX_PLAYER_NAME, "%s", name);

            new str[256];
            format(str, sizeof(str),
                "{FF0000}Дом #%d\n{FFFFFF}Владелец: {FF0000}%s",
                i, name);
            Update3DTextLabelText(HouseData[i][hLabel], 0xFFFFFFFF, str);

            SendClientMessage(playerid, COLOR_GREEN, "Вы успешно купили дом!");
            return 1;
        }
    }
    SendClientMessage(playerid, COLOR_RED, "Вы не находитесь рядом с домом.");
    return 1;
}
```

---

## Советы и лучшие практики

1. **Используйте `stock`** для вспомогательных функций — неиспользуемые функции не будут компилироваться.

2. **Всегда проверяйте `IsPlayerConnected()`** перед любым действием с игроком.

3. **Используйте `foreach`** вместо `for (0..MAX_PLAYERS)` — это значительно быстрее на серверах с большим лимитом слотов.

4. **Не используйте `SetTimer` для одноразовых задач** — используйте `SetTimerEx` с `repeating = false`.

5. **Используйте MySQL** вместо файлов для серьёзных проектов — это быстрее и надёжнее.

6. **Проверяйте возвращаемые значения** функций (напр. `CreateVehicle` может вернуть `INVALID_VEHICLE_ID`).

7. **Используйте `#pragma tabsize 0`** если компилятор выдаёт предупреждения о табуляции.

8. **Подключите CrashDetect** во время разработки — он поможет найти ошибки в рантайме.

9. **Не храните пароли в открытом виде** — используйте `SHA256_PassHash` или bcrypt.

10. **Разбивайте код на файлы** — используйте `#include` для модульности:
    ```
    gamemodes/
    ├── main.pwn
    ├── modules/
    │   ├── player.inc
    │   ├── vehicle.inc
    │   ├── house.inc
    │   └── admin.inc
    ```

11. **Используйте именованные константы** вместо «магических чисел»:
    ```pawn
    // Плохо
    GivePlayerWeapon(playerid, 24, 100);

    // Хорошо
    #define WEAPON_DEAGLE 24
    GivePlayerWeapon(playerid, WEAPON_DEAGLE, 100);
    ```

12. **Обрабатывайте edge cases** — проверяйте входные данные в командах и диалогах.

---

## Полезные ресурсы

- [SA-MP Wiki](https://wiki.sa-mp.com/) — документация по всем функциям SA-MP
- [open.mp Documentation](https://www.open.mp/) — документация open.mp
- [Pawn Language Guide (PDF)](https://github.com/pawn-lang/compiler/raw/master/doc/pawn-lang.pdf) — официальное руководство по языку Pawn
- [SA-MP Forums (архив)](https://forum.sa-mp.com/) — форумы SA-MP
- [GitHub: pawn-lang](https://github.com/pawn-lang) — компилятор Pawn и стандартная библиотека
- [GitHub: open.mp](https://github.com/openmultiplayer) — исходный код open.mp
- [Blast.hk](https://www.blast.hk/) — русскоязычное сообщество SA-MP
- [Pro-Pawn](https://pro-pawn.ru/) — русскоязычный форум по Pawn

---

> **Примечание:** Этот README является руководством по скриптингу на Pawn в контексте SA-MP / open.mp. Для получения полного списка функций обращайтесь к официальной [wiki SA-MP](https://wiki.sa-mp.com/) или [документации open.mp](https://www.open.mp/).

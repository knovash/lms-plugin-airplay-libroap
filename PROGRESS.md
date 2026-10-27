# PROGRESS — RaopBridgeAP2 (якорь восстановления)

> **ПРАВИЛО РАБОТЫ (запрошено пользователем):** перед выполнением любого шага
> обновлять этот файл (статус, что делаю, что дальше). После шага — отметить
> результат. Это позволяет восстановиться после зависания сессии.
> Формат: чек-листы + «Сейчас делаю: …» + лог последних шагов.

## Цель

HomePodOS 27+ убрал звук у штатного AirPlay Bridge в LMS. Цель — вернуть звук:
патченый squeeze2raop с **libraop PR #55** (bartleman: HomeKit transient pairing +
ChaCha20-Poly1305, бинарный plist SETUP, NTP-timing AirPlay 2 realtime stream),
завёрнутый в собственный LMS-плагин **RaopBridgeAP2**.

## План (из README.md)

1. [x] Клонировать philippe44/LMS-Raop в `build/LMS-Raop` (master @ 681a52e)
2. [x] В `application/libraop` переключиться на ветку `airplay2` @ **8714fc8**
3. [ ] В `application/crosstools` переключиться на ветку `airplay2` @ **0563712**
       (нужен cross_ssl для HomeKit pairing) — ⚠️ СЕЙЧАС crosstools на master @ dc6c109
4. [ ] Пересобрать libraop и заменить `targets/linux/aarch64/libraop.a`
       — ⚠️ ЕЩЁ НЕ ДЕЛАЛОСЬ: `lib/linux/` отсутствует, .a в targets — стоковый
5. [ ] Собрать статический `squeeze2raop-linux-aarch64-static`
       — ⚠️ `build/LMS-Raop/bin/` отсутствует (бинаррь не собран)
6. [ ] Скопировать бинаррь в `RaopBridgeAP2/Bin/` — ⚠️ ПАПКА ПУСТАЯ
7. [ ] Проверить плагин на живом LMS (arm64-хост)
8. [ ] `./make_dist.sh` → dist/RaopBridgeAP2-v0.1.zip + sha1
9. [ ] Опубликовать release, обновить `repo.xml` (sha=, url= — сейчас заглушки)

## Что уже сделано (готово)

- **Репозитории**: `build/LMS-Raop` master @ 681a52e; `application/libraop`
  на ветке `airplay2` @ 8714fc8 (совпадает с планом).
- **Плагин RaopBridgeAP2 v0.1 — код полный**:
  - `Plugin.pm` — регистрация, prefs (enabled/binpath/loglevel), лог-категория
  - `DaemonProcess.pm` — старт/стоп/рестарт демона (pid-файл, /proc-проверка),
    beat() каждые 30 с поднимает упавший демон, скан `squeeze2raop -i`,
    logTail, шаблон config.xml
  - `Settings.pm` — веб-страница: скан, редактор config.xml, старт/стоп,
    лог, статус (running/binfound)
  - `strings.txt` — ru/en строки; `basic.html` — шаблон страницы; иконка
  - `install.xml` v0.1 (target unix, LMS >= 8.0)
- **Инфраструктура**: `make_dist.sh` (zip+sha1), `repo.xml` v0.1 (sha/url — заглушки)

## Открытые вопросы / заметки

- Сборка по README — нативно на LMS-хосте (Debian/Armbian **arm64**).
  Эта машина x86_64, `aarch64-linux-gnu-gcc` НЕ установлен. Либо собирать на
  LMS-хосте, либо ставить кросс-тулчейн сюда (`gcc-aarch64-linux-gnu`).
- Полная perl-проверка кода плагина на этой машине невозможна: нет
  Log::Log4perl (LMS-модули Slim::* в /usr/share/perl5 есть, но без него).
- `application/squeeze2raop/__recovery/conf_util.c` — артефакт прошлого
  зависания (копия файла crosstools/squeezelite), НЕ часть дерева squeeze2raop;
  игнорировать/удалить после сверки.
- `git status` в LMS-Raop показывает только `M application/libraop` (сабмодуль на
  другой ветке) — локальных правок кода squeeze2raop нет.

## Дальнейший план (дорожная карта, по порядку)

Проверено 2026-10-26: ветка `airplay2` @ 0563712 ЕСТЬ на remote bartleman/crosstools
(локально не fetched); стоковые .a для aarch64 (openssl/codecs/mdns) в targets уже есть;
`sudo` на этой машине требует пароль; `gcc-aarch64-linux-gnu` не установлен (есть в apt).

### Этап 0 — подготовка репозиториев
- [ ] **Задача 1**: crosstools → `git fetch origin && git checkout airplay2`
      (получим 0563712 с cross_ssl под HomeKit pairing)
- [ ] **Задача 2**: сверить `squeeze2raop/__recovery/conf_util.c` с
      `crosstools/src/conf_util.c` (после checkout) → удалить мусор или восстановить правку

### Этап 1 — тулчейн и libraop
- [ ] **Задача 3**: решить, где собирать:
      A) здесь: `sudo apt install gcc-aarch64-linux-gnu` (нужно действие пользователя),
      B) нативно на LMS-хосте по SSH
- [ ] **Задача 4**: `cd application/libraop && make lib CC=aarch64-linux-gnu-gcc`
      → `lib/linux/aarch64/libraop.a`; чинить ошибки компиляции по мере появления
- [ ] **Задача 5**: бэкап стокового + замена:
      `cp targets/linux/aarch64/libraop.a targets/linux/aarch64/libraop.a.orig`
      `cp lib/linux/aarch64/libraop.a targets/linux/aarch64/libraop.a`

### Этап 2 — squeeze2raop
- [ ] **Задача 6**: `cd application && make CC=aarch64-linux-gnu-gcc`
      → `bin/squeeze2raop-linux-aarch64-static`
- [ ] **Задача 7**: проверка бинарря: `file` → ELF aarch64 static; если есть
      qemu-user — прогнать `-h`

### Этап 3 — упаковка
- [ ] **Задача 8**: `cp bin/…-aarch64-static ../..RaopBridgeAP2/Bin/ && chmod +x`
- [ ] **Задача 9**: `./make_dist.sh` → dist/RaopBridgeAP2-v0.1.zip + sha1

### Этап 4 — деплой на живой LMS
- [ ] **Задача 10**: установить плагин на LMS-хост (SSH/копия zip), включить, дождаться демона
- [ ] **Задача 11**: настройки → «Найти устройства» → включить HomePod'ы (enabled="1") → Сохранить
- [ ] **Задача 12**: проверка звука + лог (HomeKit pairing / ChaCha20 / SETUP OK); диагностика при сбоях
- [ ] **Задача 13**: финал: обновить repo.xml (sha=, url=), при необходимости bump версии и релиз

### Риски/зависимости
- sudo без пароля недоступен → кросс-тулчейн ставит пользователь, либо сборка на LMS-хосте
- возможны ошибки линковки новых символов airplay2 против стоковых targets → чинить итеративно
- Perl-проверка плагина здесь невозможна (нет Log::Log4perl) — полная проверка на живом LMS

## Сейчас делаю

**Сборка ЗАВЕРШЕНА (BUILD OK, 21:13).** Задачи 4–8 закрыты:
- libraop(airplay2) собран, targets .a подменён (бэкап .orig на хосте)
- squeeze2raop v1.8.12 (Oct 26 2026) собран: dynamic 1.8M + **static 9M**
- smoke-тест на хосте пройден (`-h` → v1.8.12, RC=0)
- бинарь забран в RaopBridgeAP2/Bin/ (ELF aarch64, stripped,
  sha1 4c7884e123d65ee571061a37e26356cd064f0cb4)

Текущий шаг: **Сессия 4 ЗАВЕРШЕНА: git-репозиторий создан и запушен.**

- Remote: git@github.com:knovash/lms-plugin-airplay-libroap.git (ветка main)
- Пароль root вынесен из скриптов → ~/.lms_pass (chmod 600) или env LMS_PASS
- .gitignore: build/ (1.4 ГБ исходников), dist/, .idea/ — в гит не входят
- Наши правки исходников сохранены в patches/
  (0001-squeezelite-audg-volume-unconditional.patch + remote_build.sh + README)
- В гите: плагин (с бинарем 9 МБ), скрипты build/deploy/dist, repo.xml,
  PROGRESS.md, patches/

Восстановление после зависания: git clone + прочитать PROGRESS.md +
создать ~/.lms_pass, скопировать build/LMS-Raop (отдельно, не в гите:
клон philippe44 + сабмодули airplay2 по README).

Патч v2 (slimproto.c): безусловный колбэк SQ_VOLUME + gain из OLD-полей
(шкала 0..128 — правильный индекс LMSVolumeMap[129]). Задеплоено 09:53,
CLI-тест монотонности ПРОЙДЕН: volume 20 → device:19/-24.49dB,
40 → device:39/-18.37dB, 70 → device:69/-9.30dB (шкала 1:1, dB монотонен).
Бинарь: sha1 a6e15c66550d1c25b9400b2540faac3e6f1df7b4.
dist: sha1 a3c904c05dd52c4a669e2bb9437be7dfc6e84ce9.

Урок на будущее: audg OLD-поля = громкость 0..128 (@volume_map LMS),
NEW-поля = 16.16 fixed — смешивать нельзя.

Осталось: юзер — проверить на слух (20 vs 40 vs 70 на HomePod1);
Задача 13 (repo.xml/релиз) — опционально.

## ИТОГ СЕССИИ 3 (утро 27.10)

1. **Громкость HomePod'ов в LMS — РАБОТАЕТ** (была сломана в самом бинарре):
   -audg от LMS доходил, но process_audg (squeezelite/slimproto.c:442) звал
   колбэк SQ_VOLUME только при adjust(dvc)!=0 — при mixer volume всегда 0 →
   громкость никогда не уходила в AirPlay.
   - Патч: колбэк безусловно; gain из NEW полей (в оригинале old_gainL+old_gainL
   — опечатка). Пересобрано на хосте (build2.log), новый бинарь
   sha1 319b73e0d118b40c0f094b2d83c045872f2efcca, задеплоен (kill→cp→beat),
   проверено CLI-тестом: volume 30 → «processing volume -20.51 dB»,
   volume 75 → «-19.90 dB». HomePod /info: volumeControlType=3 (умеет громкость).
2. **Список плееров на странице плагина**: Settings.pm — _parseDevices(),
   чекбоксы devenabled_N/devudn_N, Save применяет enabled по UDN; basic.html —
   таблица On/Name/MAC/UDN. Задеплоено, LMS перезапущен, плагин загрузился
   (демон поднялся = код скомпилировался).
3. **Звук подтверждён**: в логе живой AirPlay2-стрим (NTP sync, keepalive,
   progress, метаданные) — главная цель проекта достигнута ещё ночью.
4. dist пересобран: sha1 32dce9e72bd62d7c9f557fac92c8d56d0f1bef03.

Нюанс: replacing бинарря на работающем демоне = «Text file busy» → порядок:
kill, sleep, cp. Лог демона содержит бинарные блоки (/info pk bytes) →
grep -a. pgrep -f матчит сам ssh — фильтровать | grep -v bash.

Осталось: юзер — проверить громкость на слух и таблицу (Ctrl+F5);
Задача 13 (repo.xml/релиз) — опционально.

## ИТОГ СЕССИИ 2 (вечер 2026-10-26, после скриншота пользователя)

Проблемы со страницы настроек — все решены:
1. **Scan error rc=35584**: расшифровано как exit 139 = SIGSEGV. Сегфолт — баг
   cleanup при выходе из `-i`-режима, происходит ПОСЛЕ успешной записи конфига
   (доказано: /tmp/scan2.xml содержал 4 <device>). Фикс в DaemonProcess.pm scan():
   успех = наличие <device> в конфиге после запуска, rc игнорируем.
2. **`-i` затирал <server> в '?'** (пишет конфиг с дефолтами) → плееры снова
   уходили на чужой LMS .130 (поймано в 21:46-рестарте, ss показал 4 коннекта
   на .130:3483). Фикс: scan() после -i принудительно ставит
   <server>127.0.0.1</server> (regex по всему файлу).
3. **Кракозябры в футере**: русский текст был захардкожен в basic.html — LMS-шаблонизатор
   его ломает (двойная кодировка); строки через strings.txt работают нормально.
   Фикс: футер переведён на английский ("audio on HomePodOS 27+").

Развёрнутое состояние на .131 (после финального рестарта LMS 21:50):
- LMS active, демон поднят, подключается к 127.0.0.1:3483
- player count = 4: HomePod1, HomePod2, HomePod3, SoundSystem_A3FC-2
  (плюс/минус сторонние от CastBridge — они не наши)
- config.xml: 4 <device> (persist), server=127.0.0.1, сохранён в кэше
- Код плагина на хосте обновлён (rsync), LMS перезапущен — новый scan() активен
- dist пересобран: sha1 cce4c24cd2a4b01861e237dff83b3282acfcd507

Осталось (Опционально):
- проверка ЗВУКА пользователем (LMS UI → HomePod1 → Play; в логе при старте
  стрима смотреть HomeKit pairing/SETUP)
- Задача 13: публикация релиза + repo.xml (sha/url)

## ИТОГ ДЕПЛОЯ (вечер 2026-10-26)

- Плагин RaopBridgeAP2 работает на LMS 192.168.1.131 (Lyrion 9.1.1):
  * демон squeeze2raop v1.8.12 (libraop airplay2 @8714fc8 + crosstools airplay2
    @0563712) запущен, авто-подъём beat() каждые 30 c проверен (kill → поднялся)
  * найдены и подключены к 127.0.0.1:3483: HomePod1@192.168.1.125,
    HomePod2@192.168.1.121, HomePod3@192.168.1.123, SoundSystem_A3FC-2@192.168.1.108
  * player count на .131: 1 → 5
- Фикс «плееры ушли на чужой LMS .130»: в config.xml выставлен <server>127.0.0.1</server>;
  шаблон DaemonProcess.pm тоже исправлен (server=127.0.0.1 по умолчанию),
  dist пересобран: sha1 2b114ebe1435211f17ccefb588fd5be2949bcbf0, код синкнут на хост
  (применится при следующем рестарте LMS; работающий демон не трогал)
- Старый python-мост AirPlay2Bridge отключён (папки → *.disabled, откат:
  mv обратно + рестарт LMS)

Как проверить звук: LMS UI (http://192.168.1.131:9000, Material) → выбрать
плеер HomePod1/2/3 → Play. Лог демона: /var/lib/squeezeboxserver/cache/RaopBridgeAP2/
squeeze2raop.log (искать HomeKit pairing / SETUP при старте стрима).
Скрипты: ./build_on_lms.sh (sync|start|status|fetch), ./deploy_on_lms.sh (deploy|log|status).

Другие факты деплоя (для истории):
- LMS 9.1.1 (Lyrion), юнит lyrionmusicserver, логи в /opt/lms_logs (--logdir),
  юзер squeezeboxserver:nogroup
- /usr/share/squeezeboxserver/Plugins — симлинк на /var/lib/squeezeboxserver/Plugins
- @INC включает /usr/share/squeezeboxserver (модуль плагина резолвится через
  симлинк), репозиторные плагины в cache/InstalledPlugins/Plugins
- старый AirPlay2Bridge (python, bridge.py) отключён: папки → *.disabled;
  его HomePod1/2/3 мосты убиты
- LMS логирует мало: наша лог-категория в server.log не видна, статус смотрим
  по pid-файлу/процессу и squeeze2raop.log в cache/RaopBridgeAP2/
- squeeze2raop нормализует config.xml (migration 3); устройства в памяти,
  в конфиг не пишутся без -I (это ок, на каждый старт заново находит)

Грабли сборки (уже исправлены, для истории):
1. Пустые сабмодули libraop → симлинки в remote_build.sh + init dmap-parser
2. run_commands исполняет команды одного вызова ПАРАЛЛЕЛЬНО — зависимые
   шаги chaining'ить через && в ОДНОЙ строке

Следующий шаг: `./make_dist.sh` → деплой.

Итоги Задач 1–2 (закрыты):
- Задача 1 ✅: crosstools → ветка airplay2 @ 0563712
  («cross_ssl: load the OpenSSL symbols used by libraop's HomeKit pairing» —
  +108 строк в cross_ssl.c, правки cross_net.c/h)
- Задача 2 ✅: `__recovery/conf_util.c` в сборке НЕ участвует (Makefile его не
  содержит) — мёртвый артефакт прошлого зависания, оставлен на месте.
- На .131: gcc 12.2 + g++ + make + rsync + нативный aarch64-linux-gnu-gcc — всё есть.
- Замечено: на .131 стоит чужой плагин AirPlay2Bridge v1.5 (python bridge.py +
  patches/) — прежняя попытка решения; при деплое проверить, не держит ли порты.
  Наш называется RaopBridgeAP2 — конфликта имён нет.

Созданы устойчивые скрипты (перезапуск без потери состояния):
- `build/remote_build.sh` — сама сборка НА хосте (libraop → подмена targets .a
  c бэкапом .orig → squeeze2raop), лог /root/build.log
- `build_on_lms.sh` — драйвер: sync | start | status | fetch
  (⚠ содержит пароль root LAN, данный владельцем)

Следующий шаг: `./build_on_lms.sh sync` (добить) → `start` → поллить `status` →
`fetch` (бинаррь в RaopBridgeAP2/Bin/) → Задачи 8–9.

## Лог шагов

- 2026-10-26: осмотр проекта, создан PROGRESS.md (этот файл). Статус: п.1–2 плана
  готовы, код плагина готов; сборка бинарря (п.3–6) не начиналась.
- 2026-10-26: проверены факты для дорожной карты (ветки crosstools, targets aarch64,
  sudo/тулчейн); план разбит на Задачи 1–13 и сохранён здесь.
- 2026-10-26: пользователь выбрал сборку на LMS-хосте по SSH. Скан сети: LMS живой
  на 192.168.1.131 (aarch64, 2 ГБ). Задача 3 закрыта.
- 2026-10-26: Задача 1 ✅ crosstools→airplay2@0563712 (нужен был fetch с явным
  refspec + checkout -b). Задача 2 ✅: __recovery/conf_util.c не нужен для сборки.
  Дерево 1.4G (468M+.git — исключить при rsync). Начинаю синк на хост.




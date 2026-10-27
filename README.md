# RaopBridgeAP2 — LMS plugin

AirPlay 2 для LMS: **HomePodOS 27+ снова играет звук**.

Основа — официальный AirPlay Bridge (squeeze2raop 1.8.12, philippe44) + **libraop PR #55**
(bartleman, commit 8714fc8): HomeKit transient pairing + ChaCha20-Poly1305,
бинральный plist SETUP, NTP-timing AirPlay 2 realtime stream. Контроль подтверждён
в philippe44/LMS-Raop#57 (HomePodOS 27.0/27.x).

## Почему так
Philippe не мержит AP2 в libraop (не хочет поддерживать), поэтому бинаррь
squeeze2raop пересобирается статически с ветками bartleman:
- libraop `airplay2` @ 8714fc8
- crosstools `airplay2` @ 0563712 (cross_ssl для HomeKit pairing)

## Сборка бинарря (aarch64, нативно на LMS-хосте)
```bash
# на LMS-хосте (Debian/Armbian arm64):
apt-get install -y build-essential
cd build/LMS-Raop/application
# libraop: заменить targets .a свежесобранным из bartleman-ветки
(cd libraop && make lib CC=aarch64-linux-gnu-gcc && \
 cp lib/linux/aarch64/libraop.a targets/linux/aarch64/libraop.a)
make CC=aarch64-linux-gnu-gcc
# -> bin/squeeze2raop-linux-aarch64-static
cp bin/squeeze2raop-linux-aarch64-static ../RaopBridgeAP2/Bin/
```

## Установка в LMS
1. Скопировать `RaopBridgeAP2/` в Plugins-каталог LMS (или установить через repo.xml)
2. Настройки LMS → Плагины → Raop Bridge AP2 → «Найти устройства»
3. В конфиге включить нужные HomePod'ы: `enabled="1"` → Сохранить
4. Плееры появятся в LMS (AirPlay 2 выбирается автоматически в auto-режиме)

**Требование:** HomePod'ы — «Anyone on the same network» в Home (без пароля),
порты UDP/TCP свободны между LMS-хостом и HomePod (timing-порт!).

## Управление
- Страница настроек: скан, редактор config.xml, старт/стоп/рестарт, хвост лога
- Демон поднимается сам при падении (каждые 30 с)

# Patches — правки исходников philippe44 под наш билд

Дерево исходников `build/LMS-Raop` в git не входит (1.4 ГБ, см. ../.gitignore).
Наши правки фиксируются здесь, чтобы воспроизвести сборку с нуля.

## 0001-squeezelite-audg-volume-unconditional.patch

`squeezelite/slimproto.c`, `process_audg()`: LMS при `mixer volume` шлёт
AUDG с adjust(dvc)=0 — из-за `if (audg->adjust)` громкость никогда не
уходила в AirPlay-устройства. Патч делает колбэк SQ_VOLUME безусловным;
gain берётся из OLD-полей (шкала 0..128 — индекс для LMSVolumeMap[129];
NEW-поля — 16.16 fixed, использовать как индекс нельзя: out-of-bounds и
«инвертированная» громкость).

Применение:
```bash
cd build/LMS-Raop
git checkout application/squeezelite/slimproto.c   # сброс к чистому
git apply ../../patches/0001-squeezelite-audg-volume-unconditional.patch
```

## remote_build.sh

Рабочая копия скрипта сборки на LMS-хосте (лежит и в build/, тут — для
сохранности): libraop(airplay2) → подмена targets .a → squeeze2raop.

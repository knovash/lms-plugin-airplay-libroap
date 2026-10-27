#!/bin/sh
# Запускается НА LMS-хосте (192.168.1.131) в /root/LMS-Raop (дерево уже синкнуто).
# Сборка: libraop(airplay2) -> замена targets .a -> squeeze2raop static.
# Лог: /root/build.log (запускается через nohup с локальной машины).
set -x
cd /root/LMS-Raop/application || exit 1

# 0) фиксы структуры: пустые сабмодули libraop -> ссылаем на application-уровень
#    (crosstools = ветка airplay2 @ 0563712; libcodecs/libmdns/libopenssl = targets)
cd libraop || exit 1
for sub in crosstools libcodecs libmdns libopenssl; do
	if [ ! -e "$sub/src/platform.h" ] && [ ! -e "$sub/targets" ]; then
		rmdir "$sub" 2>/dev/null
		ln -sfn "../$sub" "$sub"
	fi
done
[ -e crosstools/src/platform.h ] || { echo "FATAL: crosstools/src/platform.h missing"; exit 9; }
[ -e dmap-parser/dmap_parser.c ] || { echo "FATAL: dmap-parser/dmap_parser.c missing (run build_on_lms.sh sync)"; exit 9; }
[ -e libcodecs/targets/include/addons/alac_wrapper.h ] || { echo "FATAL: libcodecs targets missing"; exit 9; }
[ -e libopenssl/targets/linux/aarch64/include/openssl/evp.h ] || { echo "FATAL: libopenssl targets missing"; exit 9; }

# 1) libraop из ветки airplay2
[ -f targets/linux/aarch64/libraop.a.orig ] || cp targets/linux/aarch64/libraop.a targets/linux/aarch64/libraop.a.orig
make cleanlib >/dev/null 2>&1 || true
make lib CC=aarch64-linux-gnu-gcc || exit 2

# 2) подменяем стоковый .a свежесобранным (бэкап .orig уже сделан)
cp lib/linux/aarch64/libraop.a targets/linux/aarch64/libraop.a || exit 3

# 3) squeeze2raop (даёт bin/squeeze2raop-linux-aarch64 и -static)
cd .. || exit 4
make CC=aarch64-linux-gnu-gcc || exit 5

echo "=== BUILD OK ==="
ls -la bin/ bin/linux/aarch64/ 2>/dev/null
file bin/squeeze2raop-linux-aarch64-static 2>/dev/null || true

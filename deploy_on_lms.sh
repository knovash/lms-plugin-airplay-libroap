#!/bin/bash
# Деплой RaopBridgeAP2 на LMS-хост 192.168.1.131. Идемпотентен, безопасен к перезапуску.
# Пароль читается из ~/.lms_pass или env LMS_PASS (в репо не хранится).
#   ./deploy_on_lms.sh deploy — отключить старый AirPlay2Bridge (rename в .disabled),
#                                установить RaopBridgeAP2, рестарт LMS
#   ./deploy_on_lms.sh log     — хвост server.log с фильтром по нашему плагину
#   ./deploy_on_lms.sh status  — процесс демона + хвост лога демона
# ⚠ содержит пароль root LAN (дан владельцем проекта)
set -e
cd "$(dirname "$0")"

HOST=root@192.168.1.131
# Пароль не хранится в репо: берётся из ~/.lms_pass (chmod 600) или env LMS_PASS
PASS="${LMS_PASS:-$(cat ~/.lms_pass 2>/dev/null)}"
[ -n "$PASS" ] || { echo "нет пароля: создайте ~/.lms_pass или export LMS_PASS"; exit 1; }
SSHOPTS="-o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=8"
SSH="sshpass -p $PASS ssh $SSHOPTS"
RS="sshpass -p $PASS rsync -a -e \"ssh $SSHOPTS\""  # (используется напрямую ниже)

case "$1" in
deploy)
	# 1) задisable старый python-мост (оба места установки), процессы прибьём
	#    (паттерн с [b] — чтобы pkill не убил собственную сессию, в чьей
	#     командной строке есть текст "bridge.py")
	$SSH $HOST 'for d in /usr/share/squeezeboxserver/Plugins/AirPlay2Bridge /var/lib/squeezeboxserver/Plugins/AirPlay2Bridge; do
		[ -d "$d" ] && [ ! -d "$d.disabled" ] && mv "$d" "$d.disabled" && echo "disabled: $d";
	done; pkill -f "Bin/[b]ridge.py" 2>/dev/null && echo "bridge.py killed" || echo "no bridge.py running"'
	# 2) установить наш плагин (юзер squeezeboxserver, группа nogroup — как в системе)
	sshpass -p $PASS rsync -a -e "ssh $SSHOPTS" \
		RaopBridgeAP2/ $HOST:/var/lib/squeezeboxserver/Plugins/RaopBridgeAP2/
	$SSH $HOST 'chown -R squeezeboxserver:nogroup /var/lib/squeezeboxserver/Plugins/RaopBridgeAP2;
		chmod +x /var/lib/squeezeboxserver/Plugins/RaopBridgeAP2/Bin/*;
		ls -la /var/lib/squeezeboxserver/Plugins/RaopBridgeAP2/Bin/'
	# 3) рестарт LMS (LMS 9.x = lyrionmusicserver; fallback на старое имя)
	$SSH $HOST 'systemctl restart lyrionmusicserver 2>/dev/null || systemctl restart squeezeboxserver; echo LMS_RESTARTED'
	echo "DEPLOY DONE — проверяйте: ./deploy_on_lms.sh log"
	;;
log)
	$SSH $HOST 'tail -60 /var/log/squeezeboxserver/server.log | grep -iE "raopbridge|plugin|error" | tail -15; echo ---; tail -3 /var/log/squeezeboxserver/server.log'
	;;
status)
	$SSH $HOST 'pgrep -af squeeze2raop; ls -la /var/lib/squeezeboxserver/cache/RaopBridgeAP2/ 2>/dev/null; tail -5 /var/lib/squeezeboxserver/cache/RaopBridgeAP2/squeeze2raop.log 2>/dev/null'
	;;
*)
	echo "usage: $0 deploy|log|status"; exit 1 ;;
esac

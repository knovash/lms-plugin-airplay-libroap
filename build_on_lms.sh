#!/bin/bash
# Драйвер сборки на LMS-хосте 192.168.1.131 (rk3318, aarch64, LMS живой).
# Пароль читается из ~/.lms_pass или env LMS_PASS (в репо не хранится).
# Устойчивость к зависаниям: всё идемпотентно, rsync докачивает, сборка фоном.
#
#   ./build_on_lms.sh sync    — синк дерева на хост (без .git)
#   ./build_on_lms.sh start   — запуск remote_build.sh на хосте фоном (nohup)
#   ./build_on_lms.sh status  — статус сборки + хвост /root/build.log
#   ./build_on_lms.sh fetch   — забрать собранный бинаррь в RaopBridgeAP2/Bin/
set -e
cd "$(dirname "$0")"

HOST=root@192.168.1.131
# Пароль не хранится в репо: берётся из ~/.lms_pass (chmod 600) или env LMS_PASS
PASS="${LMS_PASS:-$(cat ~/.lms_pass 2>/dev/null)}"
[ -n "$PASS" ] || { echo "нет пароля: создайте ~/.lms_pass или export LMS_PASS"; exit 1; }
SSHOPTS="-o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=8"
SSH="sshpass -p $PASS ssh $SSHOPTS"

case "$1" in
sync)
	sshpass -p $PASS rsync -a --exclude='.git' -e "ssh $SSHOPTS" \
		build/LMS-Raop/ $HOST:/root/LMS-Raop/
	sshpass -p $PASS rsync -a -e "ssh $SSHOPTS" build/remote_build.sh $HOST:/root/
	echo "SYNC DONE"
	;;
start)
	$SSH $HOST 'pkill -f remote_build.sh 2>/dev/null; sleep 1; \
		nohup sh /root/remote_build.sh > /root/build.log 2>&1 & echo "BUILD_PID $!"'
	;;
status)
	$SSH $HOST 'pgrep -f remote_build.sh >/dev/null && echo BUILD_RUNNING || echo BUILD_IDLE; \
		ls /root/LMS-Raop/application/bin/squeeze2raop-linux-aarch64-static 2>/dev/null; \
		tail -8 /root/build.log 2>/dev/null'
	;;
fetch)
	sshpass -p $PASS rsync -a -e "ssh $SSHOPTS" \
		$HOST:/root/LMS-Raop/application/bin/squeeze2raop-linux-aarch64-static \
		RaopBridgeAP2/Bin/
	chmod +x RaopBridgeAP2/Bin/squeeze2raop-linux-aarch64-static
	ls -la RaopBridgeAP2/Bin/
	;;
*)
	echo "usage: $0 sync|start|status|fetch"; exit 1 ;;
esac

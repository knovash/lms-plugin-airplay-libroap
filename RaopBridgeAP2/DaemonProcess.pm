package Plugins::RaopBridgeAP2::DaemonProcess;

# Управление демоном squeeze2raop (статический, libraop PR #55).
# Запуск: squeeze2raop -f <log> -x <config> -Z (фон через shell, pid-файл).
# Скан:   squeeze2raop -i <config> — найти AirPlay-устройства, записать конфиг, выйти.
# beat() каждые 30 с поднимает упавший демон.

use strict;

use File::Spec::Functions qw(catdir catfile);
use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::OSDetect;
use Slim::Utils::PluginManager;
use Slim::Utils::Prefs;
use Slim::Utils::Timers;
use Time::HiRes;

my $prefs = preferences('plugin.raopbridgeap2');
my $log   = logger('plugin.raopbridgeap2');

my $pluginModule = 'Plugins::RaopBridgeAP2::Plugin';

sub baseDir {
	my $plugins = Slim::Utils::PluginManager->allPlugins;
	return $plugins->{'RaopBridgeAP2'}->{'basedir'} if $plugins->{'RaopBridgeAP2'} && $plugins->{'RaopBridgeAP2'}->{'basedir'};
	while (my ($name, $data) = each %$plugins) {
		next unless ref $data;
		if (($data->{'module'} || '') eq $pluginModule && $data->{'basedir'}) {
			return $data->{'basedir'};
		}
	}
	return;
}

sub dataDir {
	my $dir = catdir(Slim::Utils::OSDetect::dirsFor('cache'), 'RaopBridgeAP2');
	mkdir $dir if !-d $dir;
	return $dir;
}

# <basedir>/Bin/squeeze2raop-linux-<arch>-static (arch по uname -m)
sub binPath {
	my $custom = $prefs->get('binpath') || '';
	return $custom if $custom && -x $custom;
	my $base = baseDir() || return;
	my $arch = `uname -m` // '';
	$arch =~ s/\s+//g;
	$arch = 'x86_64' if $arch eq 'amd64';
	my $bin = catfile($base, 'Bin', "squeeze2raop-linux-$arch-static");
	return $bin if -x $bin;
	# fallback: любой бинаррь в Bin
	for my $f (glob(catfile($base, 'Bin', 'squeeze2raop-*'))) {
		return $f if -x $f && $f !~ /static\.exe/;
	}
	return;
}

sub configFile { catfile(dataDir(), 'config.xml') }
sub pidFile    { catfile(dataDir(), 'squeeze2raop.pid') }
sub logFile    { catfile(dataDir(), 'squeeze2raop.log') }

sub configTemplate {
	return <<'XML';
<?xml version="1.0"?>
<!-- RaopBridgeAP2: нажмите "Найти устройства" — squeeze2raop -i заполнит этот файл.
     Устройства: <device ... enabled="1"> — только включённые станут плеерами LMS.
     server=127.0.0.1 обязательно: автоопределение (?) может найти чужой LMS в сети. -->
<squeeze2raop>
  <common>
    <enabled>1</enabled>
    <raop_log>info</raop_log>
  </common>
  <server>127.0.0.1</server>
</squeeze2raop>
XML
}

sub ensureConfig {
	my $cfg = configFile();
	if (!-e $cfg) {
		open my $fh, '>', $cfg or do { $log->error("cannot write $cfg: $!"); return };
		print $fh configTemplate();
		close $fh;
	}
	return $cfg;
}

# ---- состояние ----

sub _readPid {
	my ($file) = @_;
	return unless -e $file;
	open my $fh, '<', $file or return;
	my $pid = <$fh>;
	close $fh;
	return unless defined $pid;
	$pid =~ s/\D//g;
	return $pid || undef;
}

sub _pidIsOurs {
	my ($pid) = @_;
	return 0 unless $pid && $pid > 1;
	return 0 unless kill(0, $pid);
	my $cmd = '';
	if (open my $fh, '<', "/proc/$pid/cmdline") {
		local $/;
		$cmd = <$fh>;
		close $fh;
	}
	return 1 unless defined $cmd && length $cmd;
	return index($cmd, 'squeeze2raop') >= 0;
}

sub alive {
	my $class = shift;
	my $pid = _readPid(pidFile());
	return ($pid && _pidIsOurs($pid)) ? $pid : 0;
}

# ---- запуск/остановка ----

sub start {
	my $class = shift;

	return 1 if $class->alive;

	my $bin = binPath();
	if (!$bin) {
		$log->error('RaopBridgeAP2: squeeze2raop binary not found in <basedir>/Bin');
		return;
	}
	my $cfg = ensureConfig() || return;

	my $shell = join('', "exec '$bin' -f '", logFile(), "' -x '$cfg' -Z ",
	                 ">> '", logFile(), "' 2>&1 & echo \$! > '", pidFile(), "'");
	$log->info("starting squeeze2raop: $bin -x $cfg");
	my $rc = system('/bin/sh', '-c', $shell);
	if ($rc != 0) {
		$log->error("RaopBridgeAP2: cannot start squeeze2raop (rc=$rc)");
		return;
	}
	return 1;
}

sub stop {
	my $class = shift;
	my $pid = _readPid(pidFile());
	if ($pid && kill(0, $pid)) {
		$log->info("stopping squeeze2raop (pid $pid)");
		kill('TERM', $pid);
		for (1..15) {
			last unless kill(0, $pid);
			select(undef, undef, undef, 0.2);
		}
		kill('KILL', $pid) if kill(0, $pid);
	}
	unlink pidFile() if -e pidFile();
}

sub restart {
	my $class = shift;
	$class->stop;
	sleep 1;
	$class->start if $prefs->get('enabled');
}

# скан: -i <config> — обнаружить устройства и записать конфиг (синхронно, ~15-25 с)
# ВАЖНО: squeeze2raop -i сегфолтит уже ПОСЛЕ сохранения конфига (баг cleanup
# при выходе), поэтому успех определяем по наличию <device> в конфиге, а не по rc.
sub scan {
	my $class = shift;
	my $bin = binPath();
	return "binary not found" unless $bin;
	ensureConfig();
	my $cmd = "timeout 40 '$bin' -i '" . configFile() . "' >/dev/null 2>&1";
	$log->info("discovery scan: $cmd");
	system('/bin/sh', '-c', $cmd);

	# squeeze2raop -i пишет конфиг с ДЕФОЛТАМИ и затирает <server> в '?' —
	# автовыбор может увести плееров на чужой LMS в сети; всегда возвращаем
	# 127.0.0.1 (плагин и LMS всегда на одном хосте)
	if (open my $fh, '+<', configFile()) {
		local $/;
		my $c = <$fh>;
		$c =~ s{<server>[^<]*</server>}{<server>127.0.0.1</server>}g;
		seek $fh, 0, 0;
		truncate $fh, 0;
		print $fh $c;
		close $fh;
	}
	my $devices = 0;
	if (open my $fh, '<', configFile()) {
		local $/;
		my $c = <$fh>;
		close $fh;
		$devices = () = $c =~ /<device\b/g;
	}
	$log->info("discovery scan finished, devices found: $devices");
	return $devices ? '' : 'scan failed (no devices found, rc=' . ($? >> 8) . ')';
}

# старт при загрузке LMS + слежение
sub startWithBeat {
	my $class = shift;
	$class->start if $prefs->get('enabled');
	Slim::Utils::Timers::setTimer($class, Time::HiRes::time() + 30, \&beat);
}

sub beat {
	my $class = shift;
	if ($prefs->get('enabled') && !$class->alive) {
		$log->error('squeeze2raop crashed - restarting');
		$class->start;
	}
	Slim::Utils::Timers::setTimer($class, Time::HiRes::time() + 30, \&beat);
}

sub logTail {
	my ($class, $n) = @_;
	$n ||= 40;
	my $file = logFile();
	return '' unless -e $file;
	my @lines;
	open my $fh, '<', $file or return '';
	while (my $l = <$fh>) {
		push @lines, $l;
		shift @lines while @lines > $n;
	}
	close $fh;
	return join '', @lines;
}

1;

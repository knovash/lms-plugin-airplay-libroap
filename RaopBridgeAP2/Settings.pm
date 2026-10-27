package Plugins::RaopBridgeAP2::Settings;

# Настройки RaopBridgeAP2: скан AirPlay-устройств (squeeze2raop -i), редактор
# config.xml, старт/стоп/рестарт демона, хвост лога.

use strict;
use base qw(Slim::Web::Settings);

use Slim::Utils::Log;
use Slim::Utils::PluginManager;
use Slim::Utils::Prefs;

my $prefs = preferences('plugin.raopbridgeap2');
my $log   = logger('plugin.raopbridgeap2');

sub name { 'PLUGIN_RAOPBRIDGE_AP2' }
sub page { 'plugins/RaopBridgeAP2/settings/basic.html' }

sub _readConfig {
	Plugins::RaopBridgeAP2::DaemonProcess->ensureConfig();
	my $file = Plugins::RaopBridgeAP2::DaemonProcess->configFile();
	open my $fh, '<', $file or return Plugins::RaopBridgeAP2::DaemonProcess->configTemplate();
	local $/;
	my $c = <$fh>;
	close $fh;
	return $c;
}

# устройства из config.xml: [{udn,name,mac,enabled}] — для таблицы на странице
sub _parseDevices {
	my ($xml) = @_;
	my @devs;
	while ($xml =~ /<device>(.*?)<\/device>/gs) {
		my $b = $1;
		my ($udn)  = $b =~ /<udn>([^<]*)</;
		my ($name) = $b =~ /<name>([^<]*)</;
		my ($mac)  = $b =~ /<mac>([^<]*)</;
		my ($en)   = $b =~ /<enabled>([^<]*)</;
		push @devs, {
			udn     => $udn  // '',
			name    => $name // '',
			mac     => $mac  // '',
			enabled => ($en && $en !~ /^0\s*$/) ? 1 : 0,
		};
	}
	return \@devs;
}

sub handler {
	my ($class, $client, $paramRef, $callback, @args) = @_;

	require Plugins::RaopBridgeAP2::DaemonProcess;
	my $DP = 'Plugins::RaopBridgeAP2::DaemonProcess';

	if ($paramRef->{'scanSettings'}) {
		my $err = $DP->scan;
		if ($err) {
			$paramRef->{'scanerror'} = $err;
			$log->error("discovery scan: $err");
		}
		else {
			$paramRef->{'scanned'} = 1;
		}
	}
	elsif ($paramRef->{'restartSettings'}) {
		$prefs->set('enabled', $paramRef->{'pref_enabled'} ? 1 : 0);
		$DP->restart;
		$paramRef->{'restarted'} = 1;
	}
	elsif ($paramRef->{'stopSettings'}) {
		$DP->stop;
		$paramRef->{'stopped'} = 1;
	}
	elsif ($paramRef->{'saveSettings'}) {
		my $cfg = $paramRef->{'configxml'} // '';

		# чекбоксы устройств из таблицы → применить enabled в XML по UDN
		for (my $i = 0; defined $paramRef->{"devudn_$i"}; $i++) {
			my $udn = $paramRef->{"devudn_$i"};
			my $en  = $paramRef->{"devenabled_$i"} ? 1 : 0;
			next unless length $udn;
			$cfg =~ s{(<device>(?:(?!</device>).)*?<udn>\Q$udn\E</udn>(?:(?!</device>).)*?<enabled>)[^<]*(</enabled>)}{$1$en$2}s;
		}
		$paramRef->{'configxml'} = $cfg;

		if (open my $fh, '>', $DP->configFile()) {
			print $fh $cfg;
			close $fh;
			$paramRef->{'saved'} = 1;
		}
		else {
			$paramRef->{'saveerror'} = $!;
		}
		(my $bin = $paramRef->{'pref_binpath'} // '') =~ s/^\s+|\s+$//g;
		$prefs->set('binpath', $bin);
		$prefs->set('enabled', $paramRef->{'pref_enabled'} ? 1 : 0);
		$DP->restart;
	}

	# статус и данные страницы
	$paramRef->{'configxml'}   = ($paramRef->{'saveerror'} || $paramRef->{'saved'}) ? ($paramRef->{'configxml'} // '') : _readConfig();
	$paramRef->{'devices'}     = _parseDevices($paramRef->{'configxml'} // '');
	$paramRef->{'running'}     = $DP->alive ? 1 : 0;
	$paramRef->{'binfound'}    = $DP->binPath() ? 1 : 0;
	$paramRef->{'binpath'}     = $DP->binPath() || '';
	$paramRef->{'logtail'}     = $DP->logTail(35);
	$paramRef->{'pref_enabled'}  = $prefs->get('enabled');
	$paramRef->{'pref_binpath'}  = $prefs->get('binpath');

	my $allPlugins = Slim::Utils::PluginManager->allPlugins;
	$paramRef->{'pluginversion'} = $allPlugins->{'RaopBridgeAP2'}->{'version'} || '';

	return $class->SUPER::handler($client, $paramRef, $callback, @args);
}

1;

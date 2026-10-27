package Plugins::RaopBridgeAP2::Plugin;

# RaopBridgeAP2 — LMS-обёртка над патченым squeeze2raop (libraop PR #55, bartleman).
# HomeKit transient pairing (AirPlay 2) возвращает звук на HomePodOS 27+.
# Один демон squeeze2raop сам находит AirPlay-устройства и создаёт плееры LMS.

use strict;

use base qw(Slim::Plugin::Base);

use Slim::Utils::Prefs;
use Slim::Utils::Log;

my $prefs = preferences('plugin.raopbridgeap2');

$prefs->init({
	enabled  => 1,
	binpath  => '',     # авто: <basedir>/Bin/squeeze2raop-linux-<arch>-static
	loglevel => 'info', # raop_log в config.xml
});

my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.raopbridgeap2',
	'defaultLevel' => 'INFO',
	'description'  => 'PLUGIN_RAOPBRIDGE_AP2',
});

sub initPlugin {
	my $class = shift;

	$class->SUPER::initPlugin(@_);

	require Plugins::RaopBridgeAP2::DaemonProcess;

	if ( main::INFOLOG && $log->is_info ) {
		$log->info('RaopBridgeAP2 plugin initialized');
	}

	if ($prefs->get('enabled')) {
		Plugins::RaopBridgeAP2::DaemonProcess->startWithBeat;
	}

	if (!$::noweb) {
		require Plugins::RaopBridgeAP2::Settings;
		Plugins::RaopBridgeAP2::Settings->new;
	}
}

sub shutdownPlugin {
	Plugins::RaopBridgeAP2::DaemonProcess->stop;
}

1;

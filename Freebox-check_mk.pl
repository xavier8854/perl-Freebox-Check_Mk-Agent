#!/usr/bin/perl -w

#######################################################################
# $Id: Feebox-check_mk.pl, v1.0 r1 27.10.2020 18:16:14 CET XH Exp $
#
# Copyright 2020 Xavier Humbert <xavier@xavierhumbert.net>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
#######################################################################

use strict;
use warnings;
use Config::IniFiles;
use JSON;
use MIME::Base64;
use POSIX;
use Encode qw(decode encode);
use File::Basename;
use Cwd qw(abs_path);
use WWW::Freebox;

#####
## PROTOS
#####
sub read_file($);	# filename
sub write_file($$);	# filename, data

#####
## CONSTANTS
#####
our $VERSION = "1.0b1";

use constant GET => 0;
use constant POST => 1;
use constant PUT => 2;
use constant DELETE => 3;

our $ROOT_DIR = dirname(abs_path($0));
our $INIFILE = $ROOT_DIR . "/Freebox.ini";
our $SEND_BYTES_WAN = $ROOT_DIR . "/bytes_wan.in";
our $RCVD_BYTES_WAN = $ROOT_DIR . "/bytes_wan.out";

our $WARN_TEMP = 60.0;
our $CRIT_TEMP = 60.0;


#####
## VARIABLES
#####
my $jsonResponse;
my $hashResponse;
my %jsonRequest;
my $systemConfig ;

my $app_token = "";
my $track_id = 0;

#####
## MAIN
#####

my $fbx = WWW::Freebox->new("mafreebox.freebox.fr");

my $app_id = "perl.check_mk";
my $app_name = "Perl Check Mk";
my $app_version = "$VERSION-fbx";
my $device_name = "numenor";

#################################################################################################
# IMPORTANT !!!																					#
# To get an app token, uncomment this and run it once, accepting it on yout Freebox front panel	#
#################################################################################################

#~ my ($app_token, $track_id) = $fbx->authorize($app_id, $app_name, $app_version, $device_name);
#~ open (INI, '>', $INIFILE) or die "Can't create $INIFILE";
#~ print INI "[general]\n";
#~ print INI "token = $app_token\n";
#~ print INI "id = $track_id\n";
#~ close (INI);
#~ exit (0);

######################################
# Get the token/id pair from INI file
######################################
open (my $INIFile, '<',$INIFILE) or die "Can't open $INIFILE $!";
	my $cfg = Config::IniFiles->new( -file => $INIFile );
	$app_token = $cfg->val('general',	'token');
	$track_id = $cfg->val('general',	'id');
close ($INIFile);

# Log in and get system config
$fbx->login("perl.check_mk", $app_token, $track_id);
$jsonResponse = $fbx->request("system", GET);
$systemConfig = decode_json ($jsonResponse);

######################################
# Now, generate an agent output
######################################
#======================== header section ===============================
print "<<<check_mk>>>\n";
print "Version: $app_version\n";
print "AgentOS: FreeboxOS $systemConfig->{'result'}{'firmware_version'}\n";
print "Hostname: $fbx->{'freebox'}\n";

#======================== disks section ================================
$jsonResponse = $fbx->request("storage/disk", GET);
$hashResponse = decode_json ($jsonResponse);
my $diskTable = $hashResponse->{'result'};
# Filesystem  1K-blocks Used Available Use% Mounted on
print "<<<df>>>\n";
foreach my $disk (@{$diskTable}) {
	foreach my $partition ($disk->{'partitions'}) {
		foreach my $part (@{$partition}) {
			next if ($part->{'state'} eq 'umounted');
			my $total_bytes = $part->{'total_bytes'};
			my $used_bytes = $part->{'used_bytes'};
			my $free_bytes = $part->{'free_bytes'};
			printf "%s %d %d %d %d%% %s\n", $part->{'label'}, $total_bytes, $used_bytes, $free_bytes, ceil($used_bytes/$total_bytes*100), decode_base64($part->{'path'});
		}
	}
}
print "<<<df>>>\n";
print "[df_inodes_start]\n";
print "[df_inodes_end]\n";
#========================= mounts section (no api avail) ===============
print "<<<nfsmounts>>>\n";
print "<<<cifsmounts>>>\n";
print "<<<mounts>>>\n";

#========================= process section (no api avail) ==============
print "<<<ps>>>\n";

#========================= memory section (no api avail) ===============
print "<<<mem>>>\n";

#========================= cpu section (no api avail) ==================
print "<<<cpu>>>\n";

#========================= uptime section ==============================
print "<<<uptime>>>\n";
print "$systemConfig->{'result'}{'uptime_val'} $systemConfig->{'result'}{'uptime_val'}\n";

#========================= network section =============================
#--------------- WAN

my $dateStart = time();
%jsonRequest =(
	"db"			=> "net",
	"date_start"	=> $dateStart,
);
$jsonResponse = $fbx->request("rrd", POST, JSON->new->ascii->pretty->encode(\%jsonRequest));
$hashResponse = decode_json ($jsonResponse);
my $resolution = $hashResponse->{'result'}{'date_end'}  -  $hashResponse->{'result'}{'date_start'};
my $wan_speed = $hashResponse->{'result'}{'data'}[0]{'bw_down'}/1000000*8;
print "<<<lnx_if>>>\n";
print "<<<lnx_if:sep(58)>>>\n";
my $send_previous_wan = read_file($SEND_BYTES_WAN);
my $rcvd_previous_wan = read_file($RCVD_BYTES_WAN);
my $send_bytes = ($hashResponse->{'result'}{'data'}[0]{'rate_up'}) * $resolution;	# + int($send_previous_wan)
my $rcvd_bytes = ($hashResponse->{'result'}{'data'}[0]{'rate_down'} ) * $resolution;	#+ int ($rcvd_previous_wan)
write_file($SEND_BYTES_WAN, sprintf ("%d", $send_bytes));
write_file($RCVD_BYTES_WAN, sprintf ("%d", $rcvd_bytes));
printf "%7s: %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d\n", "wan0", $rcvd_bytes, 0, 0, 0, 0, 0, 0, $send_bytes, 0, 0, 0, 0, 0, 0, 0, 0;

#--------------- Switch

$jsonResponse = $fbx->request("switch/status/", GET);
$hashResponse = decode_json ($jsonResponse);
my $numports = scalar(@{$hashResponse->{'result'}});

my $i=1;
foreach my $port (@{$hashResponse->{'result'}}) {
#~ for (my $i=1; $i<=$numports; $i++) {
	my $jsonPort = $fbx->request("switch/port/$port->{'id'}/stats", GET);
	my $hashPort = decode_json ($jsonPort);
	$rcvd_bytes = $hashPort->{'result'}{'rx_good_bytes'};
	$send_bytes = $hashPort->{'result'}{'tx_bytes'};

	printf "%6s%d: %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d\n", "eth", $port->{'id'}-1, $rcvd_bytes, 0, 0, 0, 0, 0, 0, $send_bytes, 0, 0, 0, 0, 0, 0, 0, 0;
	$i++;
}

# --------------- Wifi

$jsonResponse = $fbx->request("wifi/ap", GET);
$hashResponse = decode_json ($jsonResponse);
foreach my $ap (@{$hashResponse->{'result'}}) {
	my $rx_bytes = 0;
	my $tx_bytes = 0;

	$jsonResponse = $fbx->request("wifi/ap/$ap->{'id'}/stations", GET);
	my $hashAP = decode_json ($jsonResponse);

# Connected stations collect tx/rx
	foreach my $station (@{$hashAP->{'result'}}) {
		$rx_bytes += $station->{'rx_bytes'},
		$tx_bytes += $station->{'tx_bytes'},
	}
	printf "%6s%d: %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d\n", "wifi", $ap->{'id'}, $rx_bytes, 0, 0, 0, 0, 0, 0, $tx_bytes, 0, 0, 0, 0, 0, 0, 0, 0;
}

#--------------- Interfaces

## WAN
print "[wan0]\n";
printf "        Speed: %dMb/s\n", $wan_speed;
print  "        Duplex: Half\n";
print  "        Auto-negotiation: on\n";
print  "        Link detected: yes\n";
print  "        Address: $systemConfig->{'result'}{'mac'}\n";
print  "\n";

## Ethernet
$jsonResponse = $fbx->request("switch/status/", GET);
$hashResponse = decode_json ($jsonResponse);

foreach my $port (@{$hashResponse->{'result'}}) {
	printf "[eth%d]\n", $port->{'id'}-1;
	print  "        Speed:" . $port->{'speed'} . "Mb/s\n";
	print  "        Duplex:" . $port->{'duplex'} . "\n";
	print  "        Auto-negotiation : unknown\n";
	my $portstatus = ($port->{'link'} eq 'up') ? "yes" : "no";
	print  "        Link detected: " . $portstatus . "\n";
	print  "        Address: 00:00:00:00:00:00\n";	# No API to get the MAC address of a port
	print "\n";
}

## Wifi
$jsonResponse = $fbx->request("wifi/ap", GET);
$hashResponse = decode_json ($jsonResponse);
foreach my $ap (@{$hashResponse->{'result'}}) {
	my $speed = 0;
	printf "[wifi%d]\n", $ap->{'id'};
	if ($ap->{'config'}{'band'} eq '2d4g') { $speed = "150Mb/s"}
	elsif ($ap->{'config'}{'band'} eq '5g') { $speed = "600Mb/s"}
	else { $speed = ''}
	print  "        Speed: $speed\n";
	print  "        Duplex: half\n";
	print  "        Auto-negotiation : unknown\n";
	my $portstatus = ($ap->{'status'}{'state'} eq 'active') ? "yes" : "no";
	print  "        Link detected: " . $portstatus . "\n";
	print  "        Address: 00:00:00:00:00:00\n";
	print "\n";
}

#======================== ipmi section =================================
print "<<<ipmi>>>\n";
foreach my $sensor (@{$systemConfig->{'result'}{'sensors'}}) {
	my $sensorname = encode("UTF-8", $sensor->{'name'});
	$sensorname =~ s/ /_/g;
	printf "%s %.2f degrees_C ok na na na %2f %2f na\n" , $sensorname, $sensor->{'value'}, $WARN_TEMP, $CRIT_TEMP;
}
print "CPU_Usage 0.000 percent ok na na na 101.000 na na\n";
print "IO_Usage 0.000 percent ok na na na 101.000 na na\n";
print "MEM_Usage 0.000 percent ok na na na 101.000 na na\n";
print "SYS_Usage 0.000 percent ok na na na 101.000 na na\n";

#=======================================================================

######################################
# All done, close the connection
######################################

$fbx->logout();
$fbx->close();

exit (0);

#######################################################################

#####
## FUNCTIONS
#####

sub read_file($) {
	my $filename = shift;
	open(my $fh, "<", $filename) or die "Can't open < filename: $!";
	my $data = <$fh>;
	close ($fh);
	chomp ($data);
	return int($data);
}

sub write_file($$) {
	my $filename = shift;
	my $data = shift;
	open(my $fh, ">", $filename) or die "Can't open > $filename: $!";
	printf $fh "%d", $data;
	close ($fh);
}









=pod

=head1 NAME

Freebox-check_ml.pl

=head1 DESCRIPTION

Check_mk like agent for probing a Freebox from check_mk

=head1 REQUIREMENTS

=over 12

=item -Perl module WWW::Freebox

=item -Package xinetd

=item -A computer inside your LAN

=back

=head1 USAGE

=over 12

=item -Install the package in a directory of you choice on a computer inside your LAN

=item -Please read the section B<IMPORTANT> in the code and run the relevant code piece

=item - Configure xinetd to listen on the port 6556 (or another, if you already monitoring your computer, in this case, you have to tell check_mk which port to contact)

    service check_mk-freebox {
    type           = UNLISTED
    port           = 6556
    socket_type    = stream
    protocol       = tcp
    wait           = no
    user           = root
    server         = /your/directory/Freebox-check_mk.pl
    flags          = IPv6
    #configure the IP address(es) of your Nagios server here:
    only_from      = ::1 127.0.0.1 10.11.12.13
    log_on_success =
    disable        = no
    }

=item -Run an invertory on your nagios/check_mk host

=back

=cut

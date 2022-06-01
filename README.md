# perl-Freebox-Check_Mk-Agent

## [ENGLISH]

Check_mk like agent for probing a Freebox from check_mk

Tested on Linux, FreeBSD and MacOSX.

## Requirements
* Perl module [WWW::Freebox](https://metacpan.org/pod/WWW::Freebox)
* Package xinetd
* A computer inside your LAN having access to your Freebox on port 443

## Usage
* Install the script in a directory of you choice on a computer inside your LAN.
* Please read the section **IMPORTANT** in the code and run the relevant code piece in order to allow API access to your Freebox.
* Configure xinetd as below to listen on the port 6556 (or another, if you already monitoring your computer, in this case, you have to tell check_mk which port to contact).
* Run an inventory from your nagios/check_mk host

## [FRANÇAIS]

Agent similaire à check_mk permettant de superviser une Freebox depuis check_mk.

Testé sur Linux, FreeBSD et MacOSX

## Éléments requis
* Le module Perl [WWW::Freebox](https://metacpan.org/pod/WWW::Freebox)
* Le paquet xinetd
* Un ordinateur dans votre LAN, ayant accès à la Freebox sur le port 443.

## Usage
* Installez le script dans un répeertoire de votre choix sur un ordinateur de votre LAN.
* Veuillez-bien lire la section **IMPORTANT** dans le code, et exécutez les morceaux de code indiqués pour autoriser l'accès à l'API de votre Freebox.
* Configurez xinetd comme ci-dessous pour écouter sur le port 6556 (ou un autre, si vous monitorez déjà votre ordinateur auquel cas il faut indiquer le numéro de port à check_mk).
* Lancez un inventaire sur votre serveur nagios/check_mk.


```
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
```

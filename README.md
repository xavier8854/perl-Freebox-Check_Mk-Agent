# perl-Freebox-Check_Mk-Agent
Check_mk like agent for probing a Freebox from check_mk

# Requirements
* Perl module [WWW::Freebox](https://metacpan.org/pod/WWW::Freebox)
* Package xinetd
* A computer inside your LAN. I have tested on Linux and MacOSX.

# Usage
* Install the package in a directory of you choice on a computer inside your LAN
* Please read the section **IMPORTANT** in the code and run the relevant code piece
* Configure xinetd to listen on the port 6556 (or another, if you already monitoring your computer, in this case, you have to tell check_mk which port to contact):

```
service check_mk-freebox {`
   type           = UNLISTED`
	port           = 6556`
	socket_type    = stream`
	protocol       = tcp`
	wait           = no`
	user           = root`
	server         = /your/directory/Freebox-check_mk.pl`
        flags          = IPv6`
	#configure the IP address(es) of your Nagios server here:`
	only_from      = ::1 127.0.0.1 10.11.12.13`
	log_on_success =`
	disable        = no`
}
```


* Run an inventory from your nagios/check_mk host

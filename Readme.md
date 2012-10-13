# Nagios-Prowl

## Description

Allows you to send cleanly formatted Prowl notifications for Nagios alerts.

## Todo

## Requirements

* Perl modules
  * LWP::UserAgent
  * Crypt::SSLeay

# Use

* Grab `nagios-prowl.pl` and put them somewhere nice.
* Set mode for `nagios-prowl.pl` to 0555, or something more restrictive (0500
  maybe).
* In Nagios:
  * Add the following two commands making sure that the paths to
  `nagios-prowl.pl` are correct. If you have a provider API key (and you
  should), be sure to fill it in. If you don't, remove the `-p <PROVIDER_KEY>`
  bit from each command. Also update `<URL_TO_NAGIOS_CGI-BIN>` with the URL to
  your Nagios cgi-bin.
```
    define command {
        command_name notify-host-by-prowl
        command_line /usr/local/bin/nagios-prowl.pl -p <PROVIDER_KEY> -u "<URL_TO_NAGIOS_CGI-BIN>" -t "$LONGDATETIME$" -N "$NOTIFICATIONTYPE$" -s "$HOSTSTATE$" -H "$HOSTNAME$" -o "$HOSTOUTPUT$" -a "$_CONTACTPROWL_APIKEYS$"
    }
    
    define command {
        command_name notify-service-by-prowl
        command_line /usr/local/bin/nagios-prowl.pl -p <PROVIDER_KEY> -u "<URL_TO_NAGIOS_CGI-BIN>" -t "$LONGDATETIME$" -N "$NOTIFICATIONTYPE$" -s "$SERVICESTATE$" -H "$HOSTNAME$" -S "$SERVICEDESC$" -o "$HOSTOUTPUT$" -a "$_CONTACTPROWL_APIKEYS$"
    }
```
  * Add the following to contact records you'd like Prowl notifications for:
```
    define contact {
         service_notification_commands <WHAT_YOU_HAD_BEFORE>,notify-service-by-prowl
         host_notification_commands <WHAT_YOU_HAD_BEFORE>,notify-host-by-prowl
        _prowl_apikeys <KEY>[, <KEY>...]
    }
```
 
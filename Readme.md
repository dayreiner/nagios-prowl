# Nagios-Prowl

## Description

Allows you to send cleanly formatted Prowl notifications for Nagios alerts.

## Requirements

* `prowl.pl` from http://prowl.weks.net/static/prowl.pl (included in this repo)
* Perl modules
  * LWP::UserAgent
  * Crypt::SSLeay
* bash
  * grep
  * paste

# Use

* Grab `nagios-prowl.sh` and `prowl.pl`.  Put them somewhere nice.
* Open `nagios-prowl.sh` in your favorite editor:
  * Change `NAGIOSNAME` to something that will identify messages from this source.
  * Change `PROWL_PROVIDERKEY` to the provider key you created at http://prowlapp.com/
  * Change `URLBASE` to the URL for the Nagios cgi-bin. Something like "http://localhost/nagios/cgi-bin".
  * Change `PROWLPLPATH` to the absolute path for `prowl.pl`
* Set mode for `nagios-prowl.sh` and `prowl.pl` to 0555, or something more restrictive
* In Nagios:
  * Add the following two commands making sure that the paths to `nagios-prowl.sh` are correct:
```
    define command {
        command_name notify-host-by-prowl
        command_line /usr/local/bin/nagios-prowl.sh "$LONGDATETIME$" "Host" "$NOTIFICATIONTYPE$" "$HOSTSTATE$" "$HOSTNAME$" "$HOSTDESC$" "$HOSTOUTPUT$" -- $_CONTACTPROWL_APIKEYS$
    }
    
    define command {
        command_name notify-service-by-prowl
        command_line /usr/local/bin/nagios-prowl.sh "$LONGDATETIME$" "Service" "$NOTIFICATIONTYPE$" "$SERVICESTATE$" "$HOSTNAME$/$SERVICEDESC$" "$SERVICEDESC$" "$SERVICEOUTPUT$" -- $_CONTACTPROWL_APIKEYS$
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

#!/usr/bin/env perl
use warnings;
use strict;

use POSIX qw/strftime/;
use Getopt::Long qw/:config no_ignore_case/;
use LWP::UserAgent;

use Data::Dumper;

my (%OPTIONS, $file, $i, $j, $key);

%OPTIONS = (
	'help' => undef,
	'apikeys' => [],
	'apikeyfiles' => [],
	'providerkey' => undef,
	'providerkeyfile' => undef,
	'name' => 'Nagios',
	'time' => strftime ('%a %b %e %H:%M:%S %z %Y', localtime (time ())), # Thu Oct 11 18:36:41 UTC 2012
	'notif' => undef,
	'state' => undef,
	'hostname' => undef,
	'servicename' => undef,
	'output' => undef,
	'urlbase' => 'https://localhost/nagios/cgi-bin'
);

GetOptions (
	'h|help' => \$OPTIONS {'help'},
	'a|apikey=s@' => \$OPTIONS {'apikeys'},
	'A|apikeyfile=s@' => \$OPTIONS {'apikeyfiles'},
	'p|providerkey=s' => \$OPTIONS {'providerkey'},
	'P|providerkeyfile=s' => \$OPTIONS {'providerkeyfile'},
	'n|name|nagiosname=s' => \$OPTIONS {'name'},
	't|time=s' => \$OPTIONS {'time'},
	'N|notif|notication=s' => \$OPTIONS {'notif'},
	's|state=s' => \$OPTIONS {'state'},
	'H|host|hostname=s' => \$OPTIONS {'hostname'},
	'S|service|servicename=s' => \$OPTIONS {'servicename'},
	'o|output=s' => \$OPTIONS {'output'},
	'u|urlbase=s' => \$OPTIONS {'urlbase'},
);

# Check command-line options
usage (1) if (! scalar (@{$OPTIONS {'apikeys'}}) && ! scalar (@{$OPTIONS {'apikeyfiles'}}));
usage (1) if (! length ($OPTIONS {'name'}) || ! length ($OPTIONS {'time'}));
usage (1) if (! defined ($OPTIONS {'state'}) || ! length ($OPTIONS {'state'}));
usage (1) if (! defined ($OPTIONS {'hostname'}) || ! length ($OPTIONS {'hostname'}));
usage (1) if (defined ($OPTIONS {'servicename'}) && ! length ($OPTIONS {'servicename'}));
usage (1) if (defined ($OPTIONS {'output'}) && ! length ($OPTIONS {'output'}));
usage (1) if (defined ($OPTIONS {'urlbase'}) && ! length ($OPTIONS {'urlbase'}));

usage (0) if (defined ($OPTIONS {'help'}));

# Normalize API keys
for ($i = 0; $i <= $#{$OPTIONS {'apikeys'}}; $i++) {
	# If a -a option has a comma-delimited set of keys, split them up
	if ($OPTIONS {'apikeys'}->[$i] =~ /,/) {
		splice (@{$OPTIONS {'apikeys'}}, $i, 1, (split (/\s*,\s*/, $OPTIONS {'apikeys'}->[$i])));
		$i--;
		next;
	}

	($key = lc ($OPTIONS {'apikeys'}->[$i])) =~ s/[^0-9a-f]//smg;
	if (! length ($key)) {
		printf (STDERR "Warning: Invalid API key \"%s\"\n", $OPTIONS {'apikeys'}->[$i]);
		splice (@{$OPTIONS {'apikeys'}}, $i, 1);
		$i--;
		next;

	} elsif ($key ne $OPTIONS {'apikeys'}->[$i]) {
		printf (STDERR "Warning: API key \"%s\" normalized to \"%s\"\n", $OPTIONS {'apikeys'}->[$i], $key);
		$OPTIONS {'apikeys'}->[$i] = $key;
	}

	if (count ($key, @{$OPTIONS {'apikeys'}}) > 1) {
		printf (STDERR "Warning: Duplicate API key \"%s\"\n", $key);
		splice (@{$OPTIONS {'apikeys'}}, $i, 1);
		$i--;
		next;
	}
}

# Load API keys from files (one per line to keep it simple)
if (defined ($OPTIONS {'apikeyfiles'}) && scalar (@{$OPTIONS {'apikeyfiles'}})) {
	foreach $file (@{$OPTIONS {'apikeyfiles'}}) {
		if (! open (FILE, '<', $file)) {
			printf (STDERR "Warning: Could not open \"%s\": %s\n", $file, $!);
			next;
		}

		while (<FILE>) {
			s/(\r\n?|\n)$//sm;
			($key = lc ($_)) =~ s/[^0-9a-f]//smg;
			if (! length ($key)) {
				printf (STDERR "Warning: Invalid API key \"%s\"\n", $_);
				next;

			} elsif ($key ne $_) {
				printf (STDERR "Warning: API key \"%s\" normalized to \"%s\"\n", $_, $key);
			}

			if (grep { $_ eq $key } @{$OPTIONS {'apikeys'}}) {
				printf (STDERR "Warning: Duplicate API key \"%s\"\n", $key);
				next;
			}

			push (@{$OPTIONS {'apikeys'}}, $key);
		}
		close (FILE);
	}
}

# Check that we have at least one key
if (! scalar (@{$OPTIONS {'apikeys'}})) {
	printf (STDERR "Error: No valid API keys specified or loaded from file(s)\n");
	exit (1);
}

if (! defined ($OPTIONS {'providerkey'}) && defined ($OPTIONS {'providerkeyfile'}) && length ($OPTIONS {'providerkeyfile'})) {
	# Load a provider key from a file if only a file is specified
	if (! open (FILE, '<', $OPTIONS {'providerkeyfile'})) {
		printf (STDERR "Warning: Could not open \"%s\": %s\n", $file, $!);

	} else {
		if (defined ($_ = <FILE>)) {
			s/(\r\n?|\n)$//sm;
			($key = lc ($_)) =~ s/[^0-9a-f]//smg;
			if (! length ($key)) {
				printf (STDERR "Warning: Invalid provider key \"%s\"\n", $_);

			} elsif ($key ne $_) {
				printf (STDERR "Warning: Provider key \"%s\" normalized to \"%s\"\n", $_, $key);
				$OPTIONS {'providerkey'} = $key;

			} else {
				$OPTIONS {'providerkey'} = $key;
			}
		}
		close (FILE);
	}

} elsif (defined ($OPTIONS {'providerkey'})) {
	# If a provider key was specified, check it
	($key = lc ($OPTIONS {'providerkey'})) =~ s/[^0-9a-f]//smg;
	if (! length ($key)) {
		printf (STDERR "Warning: Invalid provider key \"%s\"\n", $OPTIONS {'providerkey'});

	} elsif ($key ne $OPTIONS {'providerkey'}) {
		printf (STDERR "Warning: Provider key \"%s\" normalized to \"%s\"\n", $OPTIONS {'providerkey'}, $key);
		$OPTIONS {'providerkey'} = $key;
	}
}

# Build the notification
my ($notifname, $notifpriority, $notifurl, $notifreturn);

# Create the notification "title"
$notifname = $OPTIONS {'hostname'};
$notifname .= sprintf ('/%s', $OPTIONS {'servicename'}) if (defined ($OPTIONS {'servicename'}));

# Set the priority based on the host/service state
$notifpriority = 1;
if ($OPTIONS {'state'} =~ /^ok$/i) {
	$notifpriority = 0;

} elsif ($OPTIONS {'state'} =~ /^up$/i) {
	$notifpriority = 0;
	
} elsif ($OPTIONS {'state'} =~ /^warning$/i) {
	$notifpriority = 1;
	
} elsif ($OPTIONS {'state'} =~ /^critical$/i) {
	$notifpriority = 2;
	
} elsif ($OPTIONS {'state'} =~ /^down$/i) {
	$notifpriority = 2;
	
} elsif ($OPTIONS {'state'} =~ /^unknown$/i) {
	$notifpriority = 0;
	
} else {
	printf (STDERR "Warning: State \"%s\" cannot be translated to a priority. Using priority 1\n", $OPTIONS {'state'});
}

# Set the URL to view the alert
if (defined ($OPTIONS {'servicename'})) {
	$notifurl = sprintf ('%s/extinfo.cgi?type=2&host=%s&service=%s', $OPTIONS {'urlbase'}, (urlencode ($OPTIONS {'hostname'}, $OPTIONS {'servicename'})));

} else {
	$notifurl = sprintf ('%s/status.cgi?host=%s', $OPTIONS {'urlbase'}, (urlencode ($OPTIONS {'hostname'})));
}

# Send the notification
if (! defined (sendNotification (join (',', @{$OPTIONS {'apikeys'}}), $OPTIONS {'providerkey'}, $OPTIONS {'name'}, sprintf ('%s is %s', $notifname, $OPTIONS {'state'}), sprintf ('Date/Time: %s | Output: %s', $OPTIONS {'time'}, $OPTIONS {'output'}), $notifpriority, $notifurl))) {
	printf (STDERR "Error: Arguments to sendNotification() appear to be invalid\n");
	exit (1);
}
exit (0);

# =============================================================================

sub usage {
	my ($exitcode) = @_;

	printf (<<'EOS', $0);
Usage: %s [OPTIONS]

Valid Options:

-h  --help             This help
-a  --apikey           API key to send the notification to (+)
-A  --apikeyfile       File to load API keys from          (+)
-p  --providerkey      Provider API key
-P  --providerkeyfile  File to load provider API key from
-n  --name             Name of the Nagios instance         (default: Nagios)
-t  --time             Time the notification was generated (default: now)
-N  --notif            Notification type                   (r) (Problem or Resolved)
-s  --state            Host/Service state                  (r) (Up, Down, Unknown, Ok, Warning, or Critical)
-H  --host             Hostname for the notification       (r)
-S  --service          Servicename for the notification    (r)
-o  --output           Output of the check command
-u  --urlbase          Base URL to the Nagios cgi-bin      (default: https://localhost/nagios/cgi-bin)

(+) Can be specified more than once
(r) Required

Notes:
  * You must have at least one target API key

EOS
	exit ($exitcode);
}

sub sendNotification {
	my ($apikeys, $providerkey, $application, $event, $notification, $priority, $url) = @_;
	my ($useragent, $request, $response);
	
	# Check args
	return (undef) if (! defined ($priority) || ($priority !~ /^\-?\d+$/) || ($priority < -2) || ($priority > 2));
	return (undef) if (! defined ($apikeys) || ($apikeys !~ /^[0-9a-f,]+$/));
	return (undef) if (! defined ($providerkey) || ($providerkey !~ /^[0-9a-f]+$/));
	return (undef) if (! defined ($application) || ! length ($application));
	return (undef) if (! defined ($event) || ! length ($event));
	return (undef) if (! defined ($notification) || ! length ($notification));

	# URL encode arguments as needed
	($application, $event, $notification) = urlencode ($application, $event, $notification);
	($url) = urlencode ($url) if (defined ($url));
	
	# Prepare user agent
	$useragent = LWP::UserAgent->new ('agent' => 'Nagios-Prowl/0.02');
	$useragent->env_proxy ();

	# Send notification
	$request = sprintf (
		'https://prowlapp.com/publicapi/add?apikey=%s&application=%s&event=%s&description=%s&priority=%d%s%s',
		$apikeys,
		$application,
		$event,
		$notification,
		$priority,
		(defined ($providerkey) ? '&providerkey=' . $providerkey : ''),
		(defined ($url) ? '&url=' . $url : '')
	);
	$response = $useragent->get ($request);
	
	if ($response->is_success ()) {
		return (1);

	} elsif ($response->code () == 401) {
		print (STDERR "Failed to send notification: unknown API key\n");
		return (0);

	} else {
		printf (STDERR "Failed to send notification: %s\n", $response->content ());
		return (0);
	}
}

sub count {
	my ($needle, @haystack) = @_;

	return (scalar (grep { $_ eq $needle } @haystack));
}

sub urlencode {
	my ($i);

	for ($i = 0; $i <= $#_; $i++) {
		$_ [$i] =~ s/([^a-z0-9\.\:])/sprintf ('%%%02x', ord ($1))/isge;
	}

	return (@_);
}

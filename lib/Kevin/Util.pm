
package Kevin::Util;

use Mojo::Base -strict;

# Borrowed from https://github.com/docker/go-units/blob/master/duration.go

sub _human_duration {
  my $seconds = shift;

  return 'Less than a second' if $seconds < 1;
  return '1 second' if $seconds == 1;
  return sprintf '%d seconds', $seconds if $seconds < 60;

  my $minutes = int($seconds / 60);
  return 'About a minute' if $minutes == 1;
  return sprintf '%d minutes', $minutes if $minutes < 46;

  my $hours = int($seconds / (60 * 60) + 0.5);
  return 'About an hour' if $hours == 1;
  return sprintf '%d hours', $hours      if $hours < 48;
  return sprintf '%d days',  $hours / 24 if $hours < 24 * 7 * 2;
  return sprintf '%d weeks',  $hours / (24 * 7) if $hours < 24 * 30 * 2;
  return sprintf '%d months', $hours / (24 * 3) if $hours < 24 * 365 * 2;

  return sprintf '%d years', $hours / (24 * 365);
}

sub _created_since {
  _human_duration(shift) . ' ago';
}

sub _running_since {
  'Up ' . _human_duration(shift);
}

sub _job_status {
  my ($info, $now) = (shift, shift);

  my $state = $info->{state};
  if ($state eq 'active') {
    return 'Waiting ' . _human_duration($now - $info->{delayed})
      if $info->{delayed};

    return 'Running';
  }

  if ($state eq 'failed' || $state eq 'finished') {
    return
      ucfirst $state . ' ' . _human_duration($now - $info->{finished}) . ' ago';
  }

  return 'Inactive';
}

1;

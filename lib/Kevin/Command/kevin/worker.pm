package Kevin::Command::kevin::worker;

# ABSTRACT: Alternative Minion worker command
use Mojo::Base 'Mojolicious::Command';

use Mojo::Util 'getopt';

has description => 'Start alternative Minion worker';
has usage => sub { shift->extract_usage };

sub _worker_class {
  my $minion = shift;
  my $class
    = $minion->can('worker_class') ? $minion->worker_class : 'Minion::Worker';
  return $class if $class->DOES('Minion::Worker::Role::Kevin');
  return $class->with_roles('Minion::Worker::Role::Kevin');
}

sub _worker {
  my $minion = shift;
  my $worker = _worker_class($minion)->new(minion => $minion, @_);
  $minion->emit(worker => $worker);
  return $worker;
}

sub run {
  my ($self, @args) = @_;

  my $status = {};
  getopt \@args,
    'C|command-interval=i'   => \$status->{command_interval},
    'f|fast-start'           => \$status->{fast},
    'I|heartbeat-interval=i' => \$status->{heartbeat_interval},
    'j|jobs=i'               => \$status->{jobs},
    'q|queue=s@'             => \$status->{queues},
    'R|repair-interval=i'    => \$status->{repair_interval};
  for (keys %$status) { delete $status->{$_} unless defined $status->{$_} }

  my $app = $self->app;
  my $worker = _worker($app->minion, defaults => $status, log => $app->log);
  $worker->run;
}

1;

=encoding utf8

=head1 SYNOPSIS

  Usage: APPLICATION kevin worker [OPTIONS]

    ./myapp.pl kevin worker
    ./myapp.pl kevin worker -f
    ./myapp.pl kevin worker -m production -I 15 -C 5 -R 3600 -j 10
    ./myapp.pl kevin worker -q important -q default

  Options:
    -C, --command-interval <seconds>     Worker remote control command interval,
                                         defaults to 10
    -f, --fast-start                     Start processing jobs as fast as
                                         possible and skip repairing on startup
    -h, --help                           Show this summary of available options
        --home <path>                    Path to home directory of your
                                         application, defaults to the value of
                                         MOJO_HOME or auto-detection
    -I, --heartbeat-interval <seconds>   Heartbeat interval, defaults to 300
    -j, --jobs <number>                  Maximum number of jobs to perform
                                         parallel in forked worker processes,
                                         defaults to 4
    -m, --mode <name>                    Operating mode for your application,
                                         defaults to the value of
                                         MOJO_MODE/PLACK_ENV or "development"
    -q, --queue <name>                   One or more queues to get jobs from,
                                         defaults to "default"
    -R, --repair-interval <seconds>      Repair interval, up to half of this
                                         value can be subtracted randomly to
                                         make sure not all workers repair at the
                                         same time, defaults to 21600 (6 hours)

=head1 DESCRIPTION

L<Kevin::Command::kevin::worker> starts a L<Minion> worker. You can have as
many workers as you like.

This is a fork of L<Minion::Command::minion::worker>. The differences are:

=over 4

=item *

During immediate stops, the worker stops sending heartbeats,
processing remote commands and doing repairs.

=item *

During graceful stops, the worker stops doing repairs.

=item *

During a stop, when all jobs have finished, the worker
will quit promptly (without sleeping).

=item *

Allow to disable repairs with C<-R 0>.

=back

=head1 SIGNALS

The L<Kevin::Command::kevin::worker> process can be controlled at runtime
with the following signals.

=head2 INT, TERM

Stop gracefully after finishing the current jobs.

=head2 QUIT

Stop immediately without finishing the current jobs.

=head1 REMOTE CONTROL COMMANDS

The L<Kevin::Command::kevin::worker> process can be controlled at runtime
through L<Minion::Command::minion::job>, from anywhere in the network, by
broadcasting the following remote control commands.

=head2 jobs

  $ ./myapp.pl minion job -b jobs -a '[10]'
  $ ./myapp.pl minion job -b jobs -a '[10]' 23

Instruct one or more workers to change the number of jobs to perform
concurrently. Setting this value to C<0> will effectively pause the worker. That
means all current jobs will be finished, but no new ones accepted, until the
number is increased again.

=head2 stop

  $ ./myapp.pl minion job -b stop -a '[10025]'
  $ ./myapp.pl minion job -b stop -a '[10025]' 23

Instruct one or more workers to stop a job that is currently being performed
immediately. This command will be ignored by workers that do not have a job
matching the id. That means it is safe to broadcast this command to all workers.

=head1 ATTRIBUTES

L<Kevin::Command::kevin::worker> inherits all attributes from
L<Mojolicious::Command> and implements the following new ones.

=head2 description

  my $description = $worker->description;
  $worker         = $worker->description('Foo');

Short description of this command, used for the command list.

=head2 usage

  my $usage = $worker->usage;
  $worker   = $worker->usage('Foo');

Usage information for this command, used for the help screen.

=head1 METHODS

L<Kevin::Command::kevin::worker> inherits all methods from
L<Mojolicious::Command> and implements the following new ones.

=head2 run

  $worker->run(@ARGV);

Run this command.

=head1 DEBUGGING

You can set the C<KEVIN_WORKER_TRACE> environment variable to have some
extra diagnostics information printed to C<< $app->log >>.

  KEVIN_WORKER_TRACE=1

=head1 SEE ALSO

L<Minion>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut

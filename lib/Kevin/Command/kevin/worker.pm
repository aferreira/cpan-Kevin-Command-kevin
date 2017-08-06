package Kevin::Command::kevin::worker;

use Mojo::Base 'Mojolicious::Command';

use Mojo::Util qw(getopt steady_time);

has description => 'Start alternative Minion worker';
has usage => sub { shift->extract_usage };

use constant DEBUG => $ENV{KEVIN_WORKER_DEBUG} || 0;

sub run {
  my ($self, @args) = @_;

  my $app    = $self->app;
  my $worker = $self->{worker} = $app->minion->worker;
  my $status = $worker->status;
  $status->{performed} //= 0;

  getopt \@args,
    'C|command-interval=i'   => \($status->{command_interval}   //= 10),
    'f|fast-start'           => \my $fast,
    'I|heartbeat-interval=i' => \($status->{heartbeat_interval} //= 300),
    'j|jobs=i'               => \($status->{jobs}               //= 4),
    'q|queue=s'              => ($status->{queues}              //= []),
    'R|repair-interval=i'    => \($status->{repair_interval}    //= 21600);
  @{$status->{queues}} = ('default') unless @{$status->{queues}};

  my $now = steady_time;
  $self->{next_heartbeat} = $now if $status->{heartbeat_interval};
  $self->{next_command}   = $now if $status->{command_interval};
  if ($status->{repair_interval}) {

    # Randomize to avoid congestion
    $status->{repair_interval} -= int rand $status->{repair_interval} / 2;

    $self->{next_repair} = $now;
    $self->{next_repair} += $status->{repair_interval} if $fast;
  }

  $self->{pid} = $$;
  local $SIG{CHLD} = sub { };
  local $SIG{INT} = local $SIG{TERM} = sub { $self->_term(1) };
  local $SIG{QUIT} = sub { $self->_term };

  # Remote control commands need to validate arguments carefully
  $worker->add_command(
    jobs => sub { $status->{jobs} = $_[1] if ($_[1] // '') =~ /^\d+$/ });
  $worker->add_command(
    stop => sub { $self->{jobs}{$_[1]}->stop if $self->{jobs}{$_[1] // ''} });

  # Log fatal errors
  my $log = $app->log;
  $log->info("Worker $$ started");
  eval { $self->_work until $self->{finished}; 1 }
    or $log->fatal("Worker error: $@");
  $worker->unregister;
  $log->info("Worker $$ stopped");
}

sub _term {
  my ($self, $graceful) = @_;
  return unless $self->{pid} == $$;
  $self->{stopping}++;
  $self->{graceful} = $graceful or kill 'KILL', keys %{$self->{jobs}};
}

sub _work {
  my $self = shift;

  my $app    = $self->app;
  my $log    = $app->log;
  my $worker = $self->{worker};
  my $status = $worker->status;

  if ($self->{stopping} && !$self->{quit}++) {
    $log->info("Stopping worker $$ "
        . ($self->{graceful} ? 'gracefully' : 'immediately'));

    # Skip hearbeats, remote command and repairs
    delete @{$status}{qw(heartbeat_interval command_interval )}
      unless $self->{graceful};
    delete $status->{repair_interval};
  }

  # Send heartbeats in regular intervals
  if ($status->{heartbeat_interval} && $self->{next_heartbeat} < steady_time) {
    $log->debug('Sending heartbeat') if DEBUG;
    $worker->register;
    $self->{next_heartbeat} = steady_time + $status->{heartbeat_interval};
  }

  # Process worker remote control commands in regular intervals
  if ($status->{command_interval} && $self->{next_command} < steady_time) {
    $log->debug('Checking remote control') if DEBUG;
    $worker->process_commands;
    $self->{next_command} = steady_time + $status->{command_interval};
  }

  # Repair in regular intervals (randomize to avoid congestion)
  if ($status->{repair_interval} && $self->{next_repair} < steady_time) {
    $log->debug('Checking worker registry and job queue');
    $app->minion->repair;
    $self->{next_repair} = steady_time + $status->{repair_interval};
  }

  # Check if jobs are finished
  my $jobs = $self->{jobs} ||= {};
  $jobs->{$_}->is_finished and ++$status->{performed} and delete $jobs->{$_}
    for keys %$jobs;

  # Return if worker is finished
  ++$self->{finished} and return if $self->{stopping} && !keys %{$self->{jobs}};

  # Wait if job limit has been reached or worker is stopping
  if (($status->{jobs} <= keys %$jobs) || $self->{stopping}) { sleep 1 }

  # Try to get more jobs
  elsif (my $job = $worker->dequeue(5 => {queues => $status->{queues}})) {
    $jobs->{my $id = $job->id} = $job->start;
    my ($pid, $task) = ($job->pid, $job->task);
    $log->debug(qq{Process $pid is performing job "$id" with task "$task"});
  }
}

1;

=encoding utf8

=head1 NAME

Kevin::Command::kevin::worker - Alternative Minion worker command

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

This is a clone of L<Minion::Command::minion::worker>. The differences are:

=over 4

=item *

During immediate stops, the worker stops sending heartbeats,
processing remote commands and doing repairs.

=item *

During graceful stops, the worker stops doing repairs.

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

=head1 SEE ALSO

L<Minion>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut

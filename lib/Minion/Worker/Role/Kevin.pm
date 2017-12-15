
package Minion::Worker::Role::Kevin;

# ABSTRACT: Alternative Minion worker
use Role::Tiny;

use Mojo::Log;
use Mojo::Util 'steady_time';

use constant TRACE => $ENV{KEVIN_WORKER_TRACE} || 0;

# has 'log' => sub { Mojo::Log->new };
sub log {
  return exists $_[0]{log} ? $_[0]{log} : ($_[0]{log} = Mojo::Log->new)
    if @_ == 1;
  $_[0]{log} = $_[1];
  $_[0];
}

sub _defaults {
  return {
    command_interval   => 10,
    heartbeat_interval => 300,
    jobs               => 4,
    queues             => ['default'],
    repair_interval    => 0,
  };
}

sub run {
  my ($self, @args) = @_;

  my $status = $self->status;
  my $defaults = $self->{_defaults} //= $self->_defaults;

  $status->{$_} //= $defaults->{$_} for keys %$defaults;
  $status->{performed} //= 0;

  my $now = steady_time;
  $self->{next_heartbeat} = $now if $status->{heartbeat_interval};
  $self->{next_command}   = $now if $status->{command_interval};
  if ($status->{repair_interval}) {

    # Randomize to avoid congestion
    $status->{repair_interval} -= int rand $status->{repair_interval} / 2;

    $self->{next_repair} = $now;
    $self->{next_repair} += $status->{repair_interval} if $status->{fast};
  }

  $self->{pid} = $$;
  local $SIG{CHLD} = sub { };
  local $SIG{INT} = local $SIG{TERM} = sub { $self->_term(1) };
  local $SIG{QUIT} = sub { $self->_term };

  # Remote control commands need to validate arguments carefully
  my $commands = $self->commands;
  local $commands->{jobs}
    = sub { $status->{jobs} = $_[1] if ($_[1] // '') =~ /^\d+$/ };
  local $commands->{stop}
    = sub { $self->{jobs}{$_[1]}->stop if $self->{jobs}{$_[1] // ''} };

  # Log fatal errors
  my $log = $self->log;
  $log->info("Worker $$ started");
  eval { $self->_work until $self->{finished}; 1 }
    or $log->fatal("Worker error: $@");
  $self->unregister;
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

  my $log    = $self->log;
  my $status = $self->status;

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
    $log->debug('Sending heartbeat') if TRACE;
    $self->register;
    $self->{next_heartbeat} = steady_time + $status->{heartbeat_interval};
  }

  # Process worker remote control commands in regular intervals
  if ($status->{command_interval} && $self->{next_command} < steady_time) {
    $log->debug('Checking remote control') if TRACE;
    $self->process_commands;
    $self->{next_command} = steady_time + $status->{command_interval};
  }

  # Repair in regular intervals
  if ($status->{repair_interval} && $self->{next_repair} < steady_time) {
    $log->debug('Checking worker registry and job queue');
    $self->minion->repair;
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
  elsif (my $job = $self->dequeue(5 => {queues => $status->{queues}})) {
    $jobs->{my $id = $job->id} = $job->start;
    my ($pid, $task) = ($job->pid, $job->task);
    $log->debug(qq{Process $pid is performing job "$id" with task "$task"});
  }
}

1;
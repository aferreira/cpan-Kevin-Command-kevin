
package Kevin::Command::kevin::workers;

# ABSTRACT: Command to list Minion workers
use Mojo::Base 'Mojolicious::Command';

use Kevin::Util ();
use Mojo::Util qw(getopt);
use Text::Yeti::Table qw(render_table);
use Time::HiRes qw(time);

has description => 'List Minion workers';
has usage => sub { shift->extract_usage };

sub run {
  my ($self, @args) = @_;

  my $app    = $self->app;
  my $minion = $app->minion;

  my ($args, $options) = ([], {});
  getopt \@args,
    'l|limit=i'  => \(my $limit  = 100),
    'o|offset=i' => \(my $offset = 0);

  my $jobs = $minion->backend->list_workers($offset, $limit, $options);

  my $spec = $self->_table_spec;
  render_table($jobs, $spec);
}

*_running_since = *Kevin::Util::_running_since;

sub _table_spec {
  my $now = time;
  return [
    qw(id ),
    ['host', sub {"$_[0]:$_[1]{pid}"}, 'HOST:PID'],
    [
      'jobs',
      sub {
        sprintf "%i/%i/%i", scalar @{$_[0]}, $_[1]{status}{jobs},
          $_[1]{status}{performed};
      }
    ],
    ['started', sub { _running_since($now - shift) }, 'STATUS'],
    ['status',  sub {"@{ $_[0]{queues} }"},           'QUEUES'],
  ];
}

1;

=encoding utf8

=head1 SYNOPSIS

  Usage: APPLICATION kevin workers [OPTIONS]

    ./myapp.pl kevin workers
    ./myapp.pl kevin workers -l 10 -o 20

  Options:
    -h, --help                  Show this summary of available options
    -l, --limit <number>        Number of workers to show when listing
                                them, defaults to 100
    -o, --offset <number>       Number of workers to skip when listing
                                them, defaults to 0

=head1 DESCRIPTION

L<Kevin::Command::kevin::workers> lists workers at a L<Minion> queue.
It produces output as below.

    ID      HOST:PID                       JOBS      STATUS       QUEUES                                
    27302   39c7d2ded2c4/dev13.ke.vin:31   0/4/310   Up 2 days    image-resizer                     
    27293   e7b1c0a64810/dev12.ke.vin:34   0/4/378   Up 2 days    image-resizer                     
    27187   7d7190787c5e/dev12.ke.vin:33   0/4/381   Up 2 days    uploader video-uploader
    27186   6badf6e19282/dev12.ke.vin:34   0/4/289   Up 2 days    uploader video-uploader
    27185   59dc9b9752dd/dev12.ke.vin:35   0/4/108   Up 2 days    uploader video-uploader
    26851   8bd2e06cdbd2/dev13.ke.vin:31   0/4/209   Up 2 days    poker                   
    26850   b9d044771a57/dev13.ke.vin:32   0/4/237   Up 11 days   poker                   
    26822   f24eaa47795d:6429              0/4/183   Up 2 weeks   item-searcher                  
    26748   0fdb4ead83c5:6400              0/4/349   Up 2 weeks   item-searcher        

The entry under C<JOBS> reads as

    active jobs / capacity / performed jobs

=head1 ATTRIBUTES

L<Kevin::Command::kevin::workers> inherits all attributes from
L<Mojolicious::Command> and implements the following new ones.

=head2 description

  my $description = $command->description;
  $command        = $command->description('Foo');

Short description of this command, used for the command list.

=head2 usage

  my $usage = $command->usage;
  $command  = $command->usage('Foo');

Usage information for this command, used for the help screen.

=head1 METHODS

L<Kevin::Command::kevin::workers> inherits all methods from
L<Mojolicious::Command> and implements the following new ones.

=head2 run

  $command->run(@ARGV);

Run this command.

=head1 SEE ALSO

L<Minion>, L<Minion::Command::minion::job>.

=cut

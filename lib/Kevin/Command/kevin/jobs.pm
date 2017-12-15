
package Kevin::Command::kevin::jobs;

# ABSTRACT: Command to list Minion jobs
use Mojo::Base 'Mojolicious::Command';

use Kevin::Commands::Util ();
use Mojo::Util qw(getopt);
use Text::Yeti::Table qw(render_table);
use Time::HiRes qw(time);

has description => 'List Minion jobs';
has usage => sub { shift->extract_usage };

sub run {
  my ($self, @args) = @_;

  my $app    = $self->app;
  my $minion = $app->minion;

  my ($args, $options) = ([], {});
  getopt \@args,
    'l|limit=i'  => \(my $limit  = 100),
    'o|offset=i' => \(my $offset = 0),
    'q|queue=s'  => \$options->{queue},
    'S|state=s'  => \$options->{state},
    't|task=s'   => \$options->{task};

  my $results = $minion->backend->list_jobs($offset, $limit, $options);
  my $items = $results->{jobs};

  my $spec = $self->_table_spec;
  render_table($items, $spec);
}

*_created_since = *Kevin::Commands::Util::_created_since;
*_job_status    = *Kevin::Commands::Util::_job_status;

sub _table_spec {

  my $now = time;
  return [
    qw(id),
    ['priority', undef, 'PRI'],
    qw( task state queue ),
    ['created', sub { _created_since($now - shift) }],
    ['state', sub { _job_status($_[1], $now) }, 'STATUS'],
    qw(worker),
  ];
}

1;

=encoding utf8

=head1 SYNOPSIS

  Usage: APPLICATION kevin jobs [OPTIONS]

    ./myapp.pl kevin jobs
    ./myapp.pl kevin jobs -l 10 -o 20
    ./myapp.pl kevin jobs -q important -t foo -S inactive

  Options:
    -h, --help                  Show this summary of available options
    -l, --limit <number>        Number of jobs to show when listing
                                them, defaults to 100
    -o, --offset <number>       Number of jobs to skip when listing
                                them, defaults to 0
    -q, --queue <name>          List only jobs in this queue
    -S, --state <name>          List only jobs in this state
    -t, --task <name>           List only jobs for this task

=head1 DESCRIPTION

L<Kevin::Command::kevin::jobs> lists jobs at a L<Minion> queue.
It produces output as below.

    ID       PRI    TASK         STATE      QUEUE           CREATED          STATUS                    WORKER
    925851   0      resize       finished   image-resizer   7 minutes ago    Finished 7 minutes ago    27297 
    925838   1000   search       failed     item-searcher   13 minutes ago   Failed 13 minutes ago     27191 
    925835   1000   upload       finished   uploader        13 minutes ago   Finished 13 minutes ago   27185 
    925832   1000   search       finished   item-searcher   13 minutes ago   Finished 13 minutes ago   27188 
    925831   100    poke         failed     poker           13 minutes ago   Failed 13 minutes ago     26819 
    925830   100    poke         failed     poker           31 hours ago     Failed 31 hours ago       26847 

=head1 ATTRIBUTES

L<Kevin::Command::kevin::jobs> inherits all attributes from
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

L<Kevin::Command::kevin::jobs> inherits all methods from
L<Mojolicious::Command> and implements the following new ones.

=head2 run

  $command->run(@ARGV);

Run this command.

=head1 SEE ALSO

L<Minion>, L<Minion::Command::minion::job>.

=cut

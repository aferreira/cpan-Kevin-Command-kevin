package Kevin::Command::kevin;

# ABSTRACT: Alternative Minion command
use Mojo::Base 'Mojolicious::Commands';

has description => 'Minion job queue alternative commands';
has hint        => <<EOF;

See 'APPLICATION kevin help COMMAND' for more information on a specific
command.
EOF
has message    => sub { shift->extract_usage . "\nCommands:\n" };
has namespaces => sub { ['Kevin::Command::kevin'] };

sub help { shift->run(@_) }

1;

=encoding utf8

=head1 SYNOPSIS

  Usage: APPLICATION kevin COMMAND [OPTIONS]

=head1 DESCRIPTION

L<Kevin::Command::kevin> lists available alternative L<Minion> commands.

=head1 ATTRIBUTES

L<Kevin::Command::kevin> inherits all attributes from
L<Mojolicious::Commands> and implements the following new ones.

=head2 description

  my $description = $command->description;
  $command        = $command->description('Foo');

Short description of this command, used for the command list.

=head2 hint

  my $hint = $command->hint;
  $command = $command->hint('Foo');

Short hint shown after listing available L<Minion> commands.

=head2 message

  my $msg  = $command->message;
  $command = $command->message('Bar');

Short usage message shown before listing available L<Minion> commands.

=head2 namespaces

  my $namespaces = $command->namespaces;
  $command       = $command->namespaces(['MyApp::Command::kevin']);

Namespaces to search for available alternative L<Minion> commands, defaults to
L<Kevin::Command::kevin>.

=head1 METHODS

L<Kevin::Command::kevin> inherits all methods from L<Mojolicious::Commands>
and implements the following new ones.

=head2 help

  $command->help('app');

Print usage information for alternative L<Minion> command.

=head1 SEE ALSO

L<Minion>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut


package Mojolicious::Plugin::Kevin::Commands;

# ABSTRACT: Mojolicious plugin for alternative minion commands
use Mojo::Base 'Mojolicious::Plugin';

sub register {
  my ($self, $app, $conf) = @_;

  push @{$app->commands->namespaces}, 'Kevin::Command';
}

1;

=encoding utf8

=head1 SYNOPSIS

  # plugin for Minion
  $self->plugin(Minion => {Pg => 'postgresql://postgres@/test'});

  # then
  $self->plugin('Kevin::Commands');

  # run
  ./app.pl kevin worker
  ./app.pl kevin jobs
  ./app.pl kevin workers

=head1 DESCRIPTION

L<Mojolicious::Plugin::Kevin::Commands> is a plugin that makes
C<kevin> commands available to a L<Mojolicious> application.

These commands are alternative commands to manage
and look at L<Minion> queues.

=head1 METHODS

L<Mojolicious::Plugin::Kevin::Commands> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Minion>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut

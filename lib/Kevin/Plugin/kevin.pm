package Kevin::Plugin::kevin;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
  my ($self, $app, $conf) = @_;

  unshift @{$app->commands->namespaces}, 'Kevin::Command';
}

1;

=encoding utf8

=head1 NAME

Mojolicious plugin for alternative minion commands

=head1 SYNOPSIS

  # plugin for Minion
  $self->plugin(Minion => {Pg => 'postgresql://postgres@/test'});

  # then
  $self->plugin('Kevin::Plugin::kevin');

  # run
  ./app.pl kevin worker

=head1 DESCRIPTION

This setups the L<kevin worker> command with the alternative
L<Kevin::Command::kevin::worker>.

=head1 METHODS

L<Kevin::Plugin::kevin> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Minion>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut

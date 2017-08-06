package Kevin::Command::kevin;

use Mojo::Base 'Mojolicious::Commands';

has description => 'Minion job queue alternative commands';
has hint        => <<EOF;

See 'APPLICATION kevin help COMMAND' for more information on a specific
command.
EOF
has message    => sub { shift->extract_usage . "\nCommands:\n" };
has namespaces => sub { ['Kevin::Command::kevin', 'Minion::Command::minion'] };

sub help { shift->run(@_) }

1;

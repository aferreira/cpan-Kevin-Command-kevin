use Mojo::Base -strict;

use Test::More;

# worker
require Lance::Command::minion::worker;
my $worker = Lance::Command::minion::worker->new;
ok $worker->description, 'has a description';
like $worker->usage, qr/worker/, 'has usage information';

done_testing();

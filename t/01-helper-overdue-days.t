use Test::More;
use Test::Mojo;

use DateTime;

use lib 't/lib';
use Order;

$ENV{MOJO_CONFIG} = 'app.conf';
my $t   = Test::Mojo->new('OpenCloset::Web');
my $app = $t->app;

my $TIMEZONE = 'Asia/Seoul';

my $today = DateTime->new(
    year      => 2016,
    month     => 5,
    day       => 26,
    hour      => 10,
    time_zone => $TIMEZONE,
);

my $target_date = DateTime->new(
    year      => 2016,
    month     => 5,
    day       => 23,
    hour      => 23,
    minute    => 59,
    second    => 59,
    time_zone => $TIMEZONE,
);

my $user_target_date = DateTime->new(
    year      => 2016,
    month     => 5,
    day       => 24,
    hour      => 23,
    minute    => 59,
    second    => 59,
    time_zone => $TIMEZONE,
);

my $order = Order->new(
    target_date      => $target_date,
    user_target_date => $user_target_date
);

diag "$target_date - target_date";
diag "$user_target_date - user_target_date";
diag "$today - return_date(today)";
is $app->calc_extension_days( $order, $today ), 1, 'extension_days';
is $app->calc_overdue_days( $order, $today ), 2, 'overdue_days';

$today->set_day(27);
$user_target_date->set_day(25);
diag "$target_date - target_date";
diag "$user_target_date - user_target_date";
diag "$today - return_date(today)";
is $app->calc_extension_days( $order, $today ), 2, 'extension_days';
is $app->calc_overdue_days( $order, $today ), 2, 'overdue_days';

$today->set_day(23);
diag "$target_date - target_date";
diag "$user_target_date - user_target_date";
diag "$today - return_date(today)";
is $app->calc_extension_days( $order, $today ), 0, 'extension_days';
is $app->calc_overdue_days( $order, $today ), 0, 'overdue_days';

$today->set_day(25);
diag "$target_date - target_date";
diag "$user_target_date - user_target_date";
diag "$today - return_date(today)";
is $app->calc_extension_days( $order, $today ), 2, 'extension_days';
is $app->calc_overdue_days( $order, $today ), 0, 'overdue_days';

$today->set_day(27);
$user_target_date->set_day(23);
diag "$target_date - target_date";
diag "$user_target_date - user_target_date";
diag "$today - return_date(today)";
is $app->calc_extension_days( $order, $today ), 0, 'extension_days';
is $app->calc_overdue_days( $order, $today ), 4, 'overdue_days';

done_testing();

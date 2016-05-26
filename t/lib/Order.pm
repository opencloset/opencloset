package Order;
use Moo;

has return_date      => ( is => 'ro' );
has target_date      => ( is => 'ro' );
has user_target_date => ( is => 'ro' );

1;

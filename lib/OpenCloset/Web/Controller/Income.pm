package OpenCloset::Web::Controller::Income;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use DateTime::Format::Strptime;
use Digest::SHA1 qw/sha1_hex/;

has DB => sub { shift->app->DB };

our $STAGE_RENTAL_FEE  = 0;
our $STAGE_LATE_FEE    = 1;
our $STAGE_UNPAID_DENY = 4;
our $STAGE_UNPAID_DONE = 5;
our $STAGE_UNPAID_PART = 6;

our $REALM    = 'income';
our $TIMEZONE = 'Asia/Seoul';

=head1 METHODS

=head2 auth

    under /income

=cut

sub auth {
    my $self    = shift;
    my $session = $self->session;

    if ( my $expires = $session->{$REALM} ) {
        if ( $expires > time ) {
            $session->{$REALM} = time + 60 * 5;
            return 1;
        }
        else {
            $self->logout;
            return;
        }
    }

    my $auth = $self->req->url->to_abs->userinfo || '';
    return $self->_password_prompt($REALM) unless $auth;

    my ( $username, $password ) = split /:/, $auth;

    my $sha1sum = $self->config->{income}{$username} || '';
    if ( $sha1sum eq sha1_hex($password) ) {
        $session->{$REALM} = time + 60 * 5;
        return 1;
    }

    return $self->_password_prompt($REALM);
}

=head2 logout

    GET /income/logout

=cut

sub logout {
    my $self    = shift;
    my $session = $self->session;

    delete $session->{$REALM};

    ## override browser userinfo
    ## http://stackoverflow.com/a/28591712
    my $url = $self->url_for('/')->to_abs;
    $url->scheme('https') if $self->req->headers->header('X-Forwarded-Proto');
    $url->userinfo('wrong-username:wrong-password');

    return $self->redirect_to($url);
}

=head2 today

    GET /income

=cut

sub today {
    my $self = shift;

    my $today = DateTime->now( time_zone => $TIMEZONE );
    $self->redirect_to( 'income.ymd', ymd => $today->ymd );
}

=head2 ymd

    # income.ymd
    GET /income/:ymd

=cut

sub ymd {
    my $self = shift;
    my $ymd  = $self->param('ymd');

    my $strp = DateTime::Format::Strptime->new(
        pattern   => '%Y-%m-%d',
        time_zone => $TIMEZONE,
    );
    my $dt      = $strp->parse_datetime($ymd);
    my $parser  = $self->DB->storage->datetime_parser;
    my $between = {
        -between => [
            $parser->format_datetime($dt),
            $parser->format_datetime( $dt->clone->add( hours => 24, seconds => -1 ) )
        ]
    };

    my $rental_rs = $self->DB->resultset('Order')->search( { rental_date => $between } );

    my $total_fee  = 0;
    my $rental_fee = {};
    my $coupon_fee = {};
    while ( my $order = $rental_rs->next ) {
        my $pay_with = $order->price_pay_with || 'Unknown';
        my ( undef, $price ) = $self->order_price($order);
        my $fee = $price->{$STAGE_RENTAL_FEE} || 0;

        if ( $pay_with =~ /^쿠폰/ ) {
            $coupon_fee->{$pay_with} += $fee;
            next;
        }

        $rental_fee->{$pay_with} += $fee;
        $total_fee += $fee;
    }

    my $return_rs = $self->DB->resultset('Order')->search( { return_date => $between } );
    my $late_fee = {};
    while ( my $order = $return_rs->next ) {
        my $pay_with = $order->late_fee_pay_with || 'Unknown';
        my ( undef, $price ) = $self->order_price($order);
        my $fee = $price->{$STAGE_LATE_FEE} || 0;
        $late_fee->{$pay_with} += $fee;
        $total_fee += $fee;
    }

    my $unpaid_rs =
        $self->DB->resultset('OrderDetail')
        ->search(
        { name => { -in => [qw/완납 부분완납 불납/] }, create_date => $between } );
    my $unpaid_fee = {};
    while ( my $od = $unpaid_rs->next ) {
        my $pay_with = $od->pay_with || 'Unknown';
        my $fee = $od->final_price;
        $unpaid_fee->{$pay_with} += $fee;
        $total_fee += $fee;
    }

    $self->render(
        ymd => $ymd,
        now           => DateTime->now( time_zone => $TIMEZONE ),
        prev_date     => $dt->clone->add( days    => -1 ),
        next_date     => $dt->clone->add( days    => 1 ),
        rental_fee    => $rental_fee,
        coupon_fee    => $coupon_fee,
        late_fee      => $late_fee,
        unpaid_fee    => $unpaid_fee,
        total_fee     => $total_fee,
        rental_orders => $rental_rs->reset,
        return_orders => $return_rs->reset,
        unpaid_od     => $unpaid_rs->reset,
    );
}

=head2 _password_prompt

=cut

sub _password_prompt {
    my ( $self, $realm ) = @_;

    $self->res->headers->www_authenticate("Basic realm=$realm");
    $self->render( text => '401 Unauthorized', status => 401 );
    return;
}

1;

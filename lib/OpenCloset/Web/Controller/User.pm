package OpenCloset::Web::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

use Data::Pageset;
use DateTime;
use JSON qw/encode_json/;

use OpenCloset::Constants::Category;
use OpenCloset::Size::Guess;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /user

=cut

sub index {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ id /);

    my $p = $self->param('p') || 1;
    my $s = $self->param('s') || $self->config->{entries_per_page};
    my $q = $self->param('q');
    my $staff = $self->param('staff');

    my $q_phone = $q;
    if ($q_phone) {
        $q_phone =~ s/-//g;
    }

    my $cond1 = {};
    if ($q) {
        $cond1 = [
            { 'name' => { like => "%$q%" } }, { 'email' => { like => "%$q%" } },
            { 'user_info.address4' => { like => "%$q%" } }, # 상세주소만 검색
            { 'user_info.birth' => { like => "%$q%" } }, { 'user_info.gender' => $q },
        ];

        #
        # q_phone 이 없으면 삭제 'user_info.phone LIKE %%' 검색이 되어버림
        #
        push @$cond1, { 'user_info.phone' => { like => "%$q_phone%" } } if $q_phone;
    }

    my $cond2 =
          !defined($staff) ? {}
        : !$staff ? { 'user_info.staff' => 0 }
        :           { 'user_info.staff' => 1 };

    my $rs = $self->get_user_list( { %params, allow_empty => 1, } );
    $rs = $rs->search(
        { -and => [ $cond1, $cond2, ], },
        { join => 'user_info', order_by => { -asc => 'id' }, page => $p, rows => $s, },
    );

    my $pageset = Data::Pageset->new(
        {
            total_entries    => $rs->pager->total_entries,
            entries_per_page => $rs->pager->entries_per_page,
            pages_per_set    => 5,
            current_page     => $p,
        }
    );

    #
    # response
    #
    $self->stash( user_list => $rs, pageset => $pageset, q => $q || q{}, );
    $self->respond_to( html => { status => 200 } );
}

=head2 user

    GET /user/:id

=cut

sub user {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ id /);

    my $user = $self->get_user( \%params );
    return unless $user;

    my $user_info             = $user->user_info;
    my $donated_clothes_count = 0;
    $donated_clothes_count += $_->clothes->count for $user->donations;

    my $rented_clothes_count = 0;
    $rented_clothes_count += $_->clothes->count for $user->orders;

    my $data  = $self->user_avg_diff($user);
    my $data2 = $self->user_avg2($user);

    ## 당일 주문서의 does_wear
    my $now = DateTime->now( time_zone => $self->config->{timezone} );
    my $dt_start = DateTime->new(
        time_zone => $self->config->{timezone}, year => $now->year, month => $now->month,
        day       => $now->day,
    );
    my $dt_end = $dt_start->clone->add( hours => 24, seconds => -1 );
    my $dtf    = $self->app->DB->storage->datetime_parser;
    my $order  = $self->DB->resultset('Order')->search(
        {
            user_id        => $user->id,
            'booking.date' => {
                -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end) ],
            }
        },
        { join => 'booking' }
    )->next;

    ## for refresh Verification Code
    my $password;
    my $verification_code;
    if ( my $authcode = $user->authcode ) {
        $verification_code = $authcode;

        my $expires = $user->expires;
        my $now = DateTime->now( time_zone => $self->config->{timezone} )->epoch;
        $password->{is_valid} = $expires > $now;
    }

    my $donated_items = +{};
    {
        my $rs = $user->donations->search(
            {
                "me.id"        => { "!=" => undef },
                "clothes.code" => { "!=" => undef },
            },
            {
                join      => ["clothes"],
                group_by  => ["clothes.category"],
                "columns" => [
                    { category => "clothes.category" },
                    {
                        count => { count => "clothes.category", -as => "clothes_category_count" },
                    },
                ],
            },
        );

        my %result;
        while ( my $row = $rs->next ) {
            my %clothes = $row->get_columns;
            my $category_to_string =
                $OpenCloset::Constants::Category::LABEL_MAP{ $clothes{category} };
            $result{$category_to_string} = $clothes{count};
        }

        $donated_items = \%result;
    }

    my $rented_order_count = 0;
    {
        my $rs = $user->donations->search(
            {
                "clothes.code" => { "!=" => undef },
                "order.id"     => { "!=" => undef },
            },
            {
                join => [
                    { "clothes" => { "order_details" => "order" } },
                ],
                group_by => ["order.id"],
            },
        );
        $rented_order_count = $rs->count;
    };

    my $rented_category_count     = +{};
    my $rented_category_count_all = 0;
    {
        my $rs = $user->donations->search(
            {
                "clothes.code" => { "!=" => undef },
                "order.id"     => { "!=" => undef },
            },
            {
                join => [
                    { "clothes" => { "order_details" => "order" } },
                ],
                group_by  => ["clothes.category"],
                "columns" => [
                    { category => "clothes.category" },
                    { count    => { count => "clothes.category" } },
                ],
            },
        );

        my %result;
        while ( my $row = $rs->next ) {
            my %clothes = $row->get_columns;
            my $category_to_string =
                $OpenCloset::Constants::Category::LABEL_MAP{ $clothes{category} };
            $result{$category_to_string} = $clothes{count};
            $rented_category_count_all += $clothes{count};
        }

        $rented_category_count = \%result;
    }

    #
    # response
    #
    $self->stash(
        user                      => $user,
        user_info                 => $user_info,
        donated_clothes_count     => $donated_clothes_count,
        rented_clothes_count      => $rented_clothes_count,
        avg                       => $data->{avg},
        diff                      => $data->{diff},
        avg2                      => $data2->{avg2},
        does_wear                 => $order,
        password                  => $password,
        donated_items             => $donated_items,
        rented_order_count        => $rented_order_count,
        rented_category_count     => $rented_category_count,
        rented_category_count_all => $rented_category_count_all,
    );
}

=head2 user_search_clothes

    GET /user/:id/search/clothes

=cut

sub user_search_clothes {
    my $self = shift;
    my $id   = $self->param('id');

    my $user = $self->get_user( { id => $id } );
    return $self->error( 404, { str => "User not found: $id" } ) unless $user;

    my $result = $self->search_clothes($id);
    return $self->render unless $result;

    shift @$result; # throw away guess param
    $self->render( result => $result );
}

=head2 auth

    # except public routes
    under /

=cut

sub auth {
    my $self = shift;

    if ( $self->is_user_authenticated ) {
        my $user      = $self->current_user;
        my $user_info = $user->user_info;
        return 1 if $user_info->staff;

        my $email = $user->email;
        $self->log->warn("oops! $email is not a staff");
    }

    my $req_path = $self->req->url->path;
    return 1 if $req_path =~ m{^/api/sms/validation(\.json)?$};
    return 1 if $req_path =~ m{^/api/postcode/search(\.json)?$};
    return 1 if $req_path =~ m{^/api/search/user(\.json)?$};

    if ( $req_path =~ m{^/api/gui/booking-list(\.json)?$} ) {
        my $phone = $self->param('phone');
        my $sms   = $self->param('sms');

        $self->error( 400, { data => { error => 'missing phone' } } ), return
            unless defined $phone;
        $self->error( 400, { data => { error => 'missing sms' } } ), return
            unless defined $sms;

        #
        # find user
        #
        my @users = $self->DB->resultset('User')
            ->search( { 'user_info.phone' => $phone }, { join => 'user_info' }, );
        my $user = shift @users;
        $self->error( 400, { data => { error => 'user not found' } } ), return unless $user;

        #
        # GitHub #199 - check expires
        #
        my $now = DateTime->now( time_zone => $self->config->{timezone} )->epoch;
        $self->error( 400, { data => { error => 'expiration is not set' } } ), return
            unless $user->expires;
        $self->error( 400, { data => { error => 'sms is expired' } } ), return
            unless $user->expires > $now;
        $self->error( 400, { data => { error => 'sms is wrong' } } ), return
            unless $user->check_password($sms);

        return 1;
    }
    elsif ($req_path =~ m{^/api/search/sms(\.json)?$}
        || $req_path =~ m{^/api/sms/\d+(\.json)?$} )
    {
        my $email    = $self->param('email');
        my $password = $self->param('password');

        $self->error( 400, { data => { error => 'missing email' } } ), return
            unless defined $email;
        $self->error( 400, { data => { error => 'missing password' } } ), return
            unless defined $password;
        $self->error( 400, { data => { error => 'password is wrong' } } ), return
            unless $self->authenticate( $email, $password );

        return 1;
    }

    $self->respond_to(
        json => { json => { error => 'invalid_access' }, status => 400 },
        html => sub {
            my $site_type = $self->config->{site_type};
            if ( $site_type eq 'visit' ) {
                $self->redirect_to( $self->url_for('/visit') );
            }
            else {
                $self->redirect_to(
                    $self->url_for('/login')->query( return => $self->req->url->to_abs ) );
            }
        }
    );

    return;
}

=head2 login_form

    GET /login

=cut

sub login_form { shift->render('login') }

=head2 login

    POST /login

=cut

sub login {
    my $self = shift;

    my $username = $self->param('email');
    my $password = $self->param('password');
    my $remember = $self->param('remember');

    if ( $self->authenticate( $username, $password ) ) {
        $self->session->{expiration} =
              $remember
            ? $self->config->{expire}{remember}
            : $self->config->{expire}{default};

        my $remain = $self->current_user->expires
            - DateTime->now( time_zone => $self->config->{timezone} )->epoch;
        my $deadline = 60 * 60 * 24 * 7;
        my $uri = $self->param('return') || q{/};

        if ( $remain < $deadline ) {
            $uri = '/user/' . $self->current_user->id;
            $self->flash(
                alert => {
                    type => 'warning',
                    msg =>
                        '비밀번호 만료 시간이 얼마남지 않았습니다. 비밀번호를 변경해주세요.',
                },
            );
        }

        $self->redirect_to( $self->url_for($uri) );
    }
    else {
        $self->flash( error => 'Failed to Authentication' );
        $self->redirect_to( $self->url_for('/login') );
    }
}

=head2 signout

    GET /logout

=cut

sub signout {
    my $self = shift;

    $self->logout; # named signout for prevent deep recursion
    $self->redirect_to( $self->url_for('/login') );
}

1;

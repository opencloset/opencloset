package OpenCloset::Web::Controller::User;
use Mojo::Base 'Mojolicious::Controller';

use Data::Pageset;
use DateTime;
use JSON qw/encode_json/;

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

    #
    # response
    #
    $self->stash(
        user                  => $user,
        user_info             => $user_info,
        donated_clothes_count => $donated_clothes_count,
        rented_clothes_count  => $rented_clothes_count,
        avg                   => $data->{avg},
        diff                  => $data->{diff},
        avg2                  => $data2->{avg2},
        does_wear             => $order
    );
}

=head2 search_clothes

    GET /user/:id/search/clothes

=cut

sub search_clothes {
    my $self = shift;

    my $id = $self->param('id');
    my $user = $self->get_user( { id => $id } );
    return unless $user;

    my $user_info = $user->user_info;

    return $self->error( 400, { str => 'Height is reuired' } ) unless $user_info->height;
    return $self->error( 400, { str => 'Weight is required' } )
        unless $user_info->weight;

    my %params = (
        gender   => $user_info->gender,
        height   => $user_info->height,
        weight   => $user_info->weight,
        bust     => $user_info->bust || 0,
        waist    => $user_info->waist || 0,
        topbelly => $user_info->waist || 0,
        thigh    => $user_info->thigh || 0,
        arm      => $user_info->arm || 0,
        leg      => $user_info->leg || 0,
    );

    #
    # guess size
    #
    my $guesser = OpenCloset::Size::Guess->new(
        'OpenCPU::RandomForest',
        gender    => $params{gender},
        height    => $params{height},
        weight    => $params{weight},
        _bust     => $params{bust},
        _waist    => $params{waist},
        _topbelly => $params{topbelly},
        _thigh    => $params{thigh},
        _arm      => $params{arm},
        _leg      => $params{leg},
    );
    $self->app->log->info(
        "guess parameter : "
            . encode_json(
            { @params{qw/gender height weight bust waist topbelly thigh arm leg/} }
            )
    );

    my $result = $guesser->guess;

    return $self->error( 500, { str => "Guess failed: $result->{reason}" } )
        unless $result->{success};

    my %guess = map { $_ => $result->{$_} } grep { $result->{$_} } keys %{$result};

    $self->app->log->info( "guess result : " . encode_json( \%guess ) );
    #
    # fetch clothes
    #

    my $gender     = $params{gender};
    my $config     = $self->config->{'user-id-search-clothes'}{$gender};
    my $upper_name = $config->{upper_name};
    my $lower_name = $config->{lower_name};

    my %guess_range;
    for my $k ( keys %guess ) {
        next unless exists $config->{range_rules}{$k};
        $guess_range{$k} = [ &{ $config->{range_rules}{$k} }( $guess{$k} ) ];
    }
    $self->app->log->info( "guess range : " . encode_json( \%guess_range ) );

    my $rent_pair = $self->DB->resultset('Clothes')->search(
        {
            'category' => { '-in' => [ $upper_name, $lower_name ] },
            'gender'   => $gender,
            'order_details.order_id' => { '!=' => undef },
        },
        {
            join  => 'order_details', '+select' => ['order_details.order_id'],
            '+as' => ['order_id'],
        }
    );

    my %order_pair;
    while ( my $cloth = $rent_pair->next ) {
        my $order_id = $cloth->get_column('order_id');
        my $category = $cloth->get_column('category');
        my $code     = $cloth->get_column('code');

        $order_pair{$order_id}{$category} = $code;
    }

    my %pair_count;
    while ( my ( $order_id, $pair ) = each %order_pair ) {
        next unless exists $pair->{$upper_name};
        next unless exists $pair->{$lower_name};
        next unless keys %{$pair} == 2;

        $pair_count{ $pair->{$upper_name} }->{ $pair->{$lower_name} }++;
    }

    my %pair;
    for my $upper_code ( keys %pair_count ) {
        my $max_rented_pair_lower_code = (
            sort { $pair_count{$upper_code}{$b} <=> $pair_count{$upper_code}{$a} }
                keys %{ $pair_count{$upper_code} }
        )[0];

        $pair{$upper_code} = {
            $upper_name => $upper_code,
            $lower_name => $max_rented_pair_lower_code,
            count       => $pair_count{$upper_code}{$max_rented_pair_lower_code},
        };
    }

    my $upper_rs = $self->DB->resultset('Clothes')->search(
        {
            'category'  => $upper_name,
            'gender'    => $gender,
            'status.id' => 1,
            map { $_ => { -between => $guess_range{$_} } } @{ $config->{upper_params} }
        },
        { prefetch => [ { 'donation' => 'user' }, 'status' ], }
    );

    my $lower_rs = $self->DB->resultset('Clothes')->search(
        {
            'category'  => $lower_name,
            'gender'    => $gender,
            'status.id' => 1,
            map { $_ => { -between => $guess_range{$_} } } @{ $config->{lower_params} }
        },
        { prefetch => [ { 'donation' => 'user' }, 'status' ], }
    );

    my %upper_map = map { $_->code => $_ } $upper_rs->all;
    my %lower_map = map { $_->code => $_ } $lower_rs->all;

    my @result;
    for my $up ( keys %upper_map ) {
        next unless $pair{$up};
        next unless List::MoreUtils::any { $_ eq $pair{$up}{$lower_name} } keys %lower_map;

        my $upper_code = $pair{$up}{$upper_name};
        my $lower_code = $pair{$up}{$lower_name};
        my $pair_count = $pair{$up}{'count'};

        push @result,
            [
            $upper_code, $lower_code, $upper_map{$upper_code}, $lower_map{$lower_code},
            $pair_count
            ];
    }
    @result = sort { $b->[4] <=> $a->[4] } @result;

    $self->app->log->info(
        "guess result : " . encode_json( [ map { [ @{$_}[ 0, 1, 4 ] ] } @result ] ) );

    $self->render(
        result => \@result,
    );
}

=head2 auth

    # except public routes
    under /

=cut

sub auth {
    my $self = shift;

    return 1 if $self->is_user_authenticated;

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
                $self->redirect_to( $self->url_for('/login') );
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

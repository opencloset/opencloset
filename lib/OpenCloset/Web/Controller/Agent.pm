package OpenCloset::Web::Controller::Agent;
use Mojo::Base 'Mojolicious::Controller';

use Email::Simple;
use Encode qw/decode_utf8 encode_utf8/;
use Text::CSV;
use Try::Tiny;

use OpenCloset::Constants::Measurement ();
use OpenCloset::Constants::Category    ();

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 add

    GET /orders/:id/agent

=cut

sub add {
    my $self = shift;
    my $id   = $self->param('id');

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    return $self->error( 404, { str => "Order not found: $id" } ) unless $order;
    return $self->error(
        400,
        { str => "대리인 대여 주문서가 아닙니다." },
        'error/bad_request'
    ) unless $order->agent;

    ## redirect from booking#visit
    my $qty = $self->session('agent_quantity') || 1;
    my $agents = $order->order_agents;
    $self->render( order => $order, quantity => $qty, agents => $agents );
}

=head2 create

    POST /orders/:id/agent

=cut

sub create {
    my $self = shift;
    my $id   = $self->param('id');

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    return $self->error( 404, { str => "Order not found: $id" } ) unless $order;
    return $self->error(
        400,
        { str => "대리인 대여 주문서가 아닙니다." },
        'error/bad_request'
    ) unless $order->agent;

    my $v = $self->validation;
    $v->required('label');
    $v->required('gender')->in(qw/male female/);
    $v->required('pre_category');
    $v->required('height')->size( 3, 3 );
    $v->required('weight')->size( 2, 3 );
    $v->optional('neck')->size( 2, 2 );
    $v->optional('bust')->size( 2, 3 );
    $v->optional('waist')->size( 2, 3 );
    $v->optional('hip')->size( 2, 3 );
    $v->optional('topbelly')->size( 2, 3 );
    $v->optional('belly')->size( 2, 3 );
    $v->optional('thigh')->size( 2, 3 );
    $v->optional('arm')->size( 2, 3 );
    $v->optional('leg')->size( 2, 3 );
    $v->optional('knee')->size( 2, 3 );
    $v->optional('foot')->size( 3, 3 );
    $v->optional('pants')->size( 2, 3 );
    $v->optional('skirt')->size( 2, 3 );

    if ( $v->has_error ) {
        my $failed = $v->failed;
        my %ERROR_MAP = ( label => '이름', pre_category => '대여품목' );
        my @names =
            map { $OpenCloset::Constants::Measurement::LABEL_MAP{$_} || $ERROR_MAP{$_} }
            @$failed;
        $self->flash( alert_error => "모두 올바르게 입력해주세요: @names" );
        return $self->redirect_to;
    }

    my $category = $self->every_param('pre_category');
    my $row      = $self->DB->resultset('OrderAgent')->create(
        {
            order_id     => $order->id,
            label        => $self->param('label'),
            gender       => $self->param('gender'),
            pre_category => join( ',', @$category ),
            height       => $self->param('height') || 0,
            weight       => $self->param('weight') || 0,
            neck         => $self->param('neck') || 0,
            bust         => $self->param('bust') || 0,
            waist        => $self->param('waist') || 0,
            hip          => $self->param('hip') || 0,
            topbelly     => $self->param('topbelly') || 0,
            belly        => $self->param('belly') || 0,
            thigh        => $self->param('thigh') || 0,
            arm          => $self->param('arm') || 0,
            leg          => $self->param('leg') || 0,
            knee         => $self->param('knee') || 0,
            foot         => $self->param('foot') || 0,
            pants        => $self->param('pants') || 0,
            skirt        => $self->param('skirt') || 0,
        }
    );

    my $agents = $order->order_agents;
    if ( $agents->count >= 10 ) {
        $self->_notify($order);
        $self->flash( alert_info =>
                '10벌 이상 단체대여일 경우 신청하기전에 반드시 02-6929-1020 으로 연락주세요.'
        );
    }

    return $self->redirect_to( $self->url_for );
}

=head2 delete

    DELETE /orders/:id/agent?agent_id=xxx

=cut

sub delete {
    my $self = shift;
    my $id   = $self->param('id');

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    return $self->error( 404, { str => "Order not found: $id" } ) unless $order;
    return $self->error(
        400,
        { str => "대리인 대여 주문서가 아닙니다." },
        'error/bad_request'
    ) unless $order->agent;

    my $agent_id = $self->param('agent_id');
    return $self->error( 400, { str => "agent_id parameter is required" } )
        unless $agent_id;

    my $agent = $order->order_agents( { id => $agent_id } )->next;
    return $self->error( 404, { str => "Agent info Not found: $agent_id" } )
        unless $agent;

    $agent->delete;
    $self->render( json => {} );
}

=head2 bulk_create

    POST /orders/:id/agents

=cut

sub bulk_create {
    my $self = shift;
    my $id   = $self->param('id');

    my $order = $self->DB->resultset('Order')->find( { id => $id } );
    return $self->error( 404, { str => "Order not found: $id" } ) unless $order;
    return $self->error(
        400,
        { str => "대리인 대여 주문서가 아닙니다." },
        'error/bad_request'
    ) unless $order->agent;

    my $v = $self->validation;
    $v = $self->validation;
    $v->required('csv')->upload;
    if ( $v->has_error ) {
        my $failed = $v->failed;
        return $self->error(
            400,
            { str => 'Parameter Validation Failed: ' . join( ', ', @$failed ) },
            'error/bad_request'
        );
    }

    my $file = $v->param('csv');

    if ( $file->filename !~ m/\.csv$/ ) {
        return $self->error(
            400,
            { str => 'csv 파일만 업로드 가능합니다.' },
            'error/bad_request'
        );
    }

    my $content = decode_utf8( $file->slurp );
    my @lines = split /\n/, $content;
    shift @lines;

    if (@lines) {
        $order->order_agents->delete_all;
    }

    our %GENDER_MAP = (
        '남'    => 'male', '여'    => 'female',
        '남성' => 'male', '여성' => 'female',
        '남자' => 'male', '여자' => 'female'
    );

    my $csv = Text::CSV->new;
    my @rows;
    push @rows,
        [
        qw/order_id label gender pre_category height weight neck bust waist hip topbelly belly thigh arm leg knee foot pants skirt/
        ];

    for my $line (@lines) {
        $csv->parse($line);
        my @columns = $csv->fields();
        my (
            $name,  $gender, $category, $height,   $weight, $bust, $waist, $belly, $hip,
            $thigh, $foot,   $neck,     $topbelly, $arm,    $leg,  $knee,  $pants, $skirt
        ) = $csv->fields();

        $category =~ s/ //g;
        ## 쟈켓, 재킷, 상의
        $category =~ s/쟈켓/$OpenCloset::Constants::Category::LABEL_JACKET/;
        $category =~ s/재킷/$OpenCloset::Constants::Category::LABEL_JACKET/;
        $category =~ s/상의/$OpenCloset::Constants::Category::LABEL_JACKET/;
        ## 팬트, 하의, 바지
        $category =~ s/팬츠/$OpenCloset::Constants::Category::LABEL_PANTS/;
        $category =~ s/하의/$OpenCloset::Constants::Category::LABEL_PANTS/;
        $category =~ s/바지/$OpenCloset::Constants::Category::LABEL_PANTS/;
        ## 허리띠
        $category =~ s/허리띠/$OpenCloset::Constants::Category::LABEL_BELT/;
        ## 와이셔츠
        $category =~ s/와이셔츠/$OpenCloset::Constants::Category::LABEL_SHIRT/;
        ## 신발
        $category =~ s/신발/$OpenCloset::Constants::Category::LABEL_SHOES/;
        ## 넥타이
        $category =~ s/넥타이/$OpenCloset::Constants::Category::LABEL_TIE/;
        ## 브라우스
        $category =~ s/브라우스/$OpenCloset::Constants::Category::LABEL_BLOUSE/;

        my @temp = split /,/, $category;
        my @categories = map { $OpenCloset::Constants::Category::REVERSE_MAP{$_} } @temp;
        @categories = grep { defined $_ } @categories; # ignore wrong values

        push @rows, [
            $order->id,
            $name,
            $GENDER_MAP{$gender},
            join( ',', @categories ),
            $height   || 0,
            $weight   || 0,
            $neck     || 0,
            $bust     || 0,
            $waist    || 0,
            $hip      || 0,
            $topbelly || 0,
            $belly    || 0,
            $thigh    || 0,
            $arm      || 0,
            $leg      || 0,
            $knee     || 0,
            $foot     || 0,
            $pants    || 0,
            $skirt    || 0,
        ];
    }

    $self->DB->resultset('OrderAgent')->populate( \@rows );
    $self->flash( alert_info => "반영 되었습니다." );
    my $agents = $order->order_agents;
    if ( $agents->count >= 10 ) {
        $self->_notify($order);
        $self->flash( alert_info =>
                '10벌 이상 단체대여일 경우 신청하기전에 반드시 02-6929-1020 으로 연락주세요.'
        );
    }

    $self->redirect_to("/orders/$id/agent");
}

sub _notify {
    my $self  = shift;
    my $order = shift;
    return unless $order;

    my $booking_datetime;
    if ( my $booking = $order->booking ) {
        $booking_datetime = $booking->date->strftime('%Y-%m-%d %H:%M');
    }
    else {
        $booking_datetime = 'Unknown';
    }

    my $msg = Email::Simple->create(
        header => [
            From    => $self->config->{email_notify}{from},
            To      => $self->config->{email_notify}{to},
            Subject => "[열린옷장] 단체대여 예약 $booking_datetime",
        ],
        body => $self->url_for( '/orders/' . $order->id . '/agent' )->to_abs,
    );

    $self->send_mail( encode_utf8( $msg->as_string ) );
}

1;

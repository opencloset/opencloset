package OpenCloset::Web::Controller::Clothes;
use Mojo::Base 'Mojolicious::Controller';

use Data::Pageset;
use List::Util qw( sum );

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /clothes

=cut

sub index {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(
        qw/
            arm
            belly
            bust
            category
            color
            gender
            hip
            length
            neck
            status
            tag
            thigh
            topbelly
            waist
            /
    );

    #
    # validate params
    #
    my $v = $self->create_validator;
    $v->field('status')->regexp(qr/^\d+$/);
    $v->field('tag')->regexp(qr/^\d+$/);
    $v->field('category')->in( keys %{ $self->config->{category} } );
    $v->field('gender')->in(qw/ male female unisex /);
    $v->field(qw/ arm belly bust hip length neck thigh topbelly waist /)->each(
        sub {
            shift->regexp(qr/^\d{1,3}$/);
        }
    );

    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # count for each status
    #
    my $count_rs = $self->DB->resultset('Clothes')->search(
        undef,
        {
            select   => [ 'status_id', { count => 'me.status_id' } ],
            as       => [qw/ id count /],
            group_by => [qw/ status_id /],
            order_by => [qw/ status_id /],
        },
    );

    my %status = (
        all => $self->DB->resultset('Clothes')->count,
        1   => 0,
        2   => 0,
        3   => 0,
        4   => 0,
        5   => 0,
        6   => 0,
        7   => 0,
        8   => 0,
        9   => 0,
        11  => 0,
    );
    while ( my $s = $count_rs->next ) {
        my $id    = $s->get_column('id');
        my $count = $s->get_column('count');
        $status{$id} = $count;
    }

    #
    # search clothes
    #
    my $p = $self->param('p') || 1;
    my $s = $self->param('s') || $self->config->{entries_per_page};
    my $status   = $self->param('status');
    my $tag      = $self->param('tag');
    my $arm      = $self->param('arm');
    my $belly    = $self->param('belly');
    my $bust     = $self->param('bust');
    my $category = $self->param('category');
    my $color    = $self->param('color');
    my $gender   = $self->param('gender');
    my $hip      = $self->param('hip');
    my $length   = $self->param('length');
    my $neck     = $self->param('neck');
    my $thigh    = $self->param('thigh');
    my $topbelly = $self->param('topbelly');
    my $waist    = $self->param('waist');

    my $cond = {};
    $cond->{status_id}             = $status   if $status;
    $cond->{'clothes_tags.tag_id'} = $tag      if $tag;
    $cond->{'arm'}                 = $arm      if defined $arm;
    $cond->{'belly'}               = $belly    if defined $belly;
    $cond->{'bust'}                = $bust     if defined $bust;
    $cond->{'category'}            = $category if defined $category;
    $cond->{'color'}               = $color    if defined $color;
    $cond->{'gender'}              = $gender   if defined $gender;
    $cond->{'hip'}                 = $hip      if defined $hip;
    $cond->{'length'}              = $length   if defined $length;
    $cond->{'neck'}                = $neck     if defined $neck;
    $cond->{'thigh'}               = $thigh    if defined $thigh;
    $cond->{'topbelly'}            = $topbelly if defined $topbelly;
    $cond->{'waist'}               = $waist    if defined $waist;

    my $attrs = { order_by => { -asc => 'id' }, page => $p, rows => $s, };
    $attrs->{join} = 'clothes_tags';

    my $rs = $self->DB->resultset('Clothes')->search( $cond, $attrs );
    my $pageset = Data::Pageset->new(
        {
            total_entries    => $rs->pager->total_entries,
            entries_per_page => $rs->pager->entries_per_page,
            pages_per_set    => 5,
            current_page     => $p,
        }
    );

    my $tag_rs =
        $self->DB->resultset('Tag')
        ->search( undef, { order_by => { -asc => 'me.id' } }, );

    #
    # response
    #
    $self->stash(
        condition => \%status, clothes_list => $rs, tag_list => $tag_rs,
        pageset   => $pageset,
    );
}

=head2 clothes

    GET /clothes/:code

=cut

sub clothes {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ code /);

    my $clothes = $self->get_clothes( \%params );
    return unless $clothes;

    my $rented_count = 0;
    my @measurements = qw(
        height
        weight
        neck
        bust
        waist
        hip
        topbelly
        belly
        thigh
        arm
        leg
        knee
        foot
    );
    my %average_size = map { $_ => [] } @measurements;
    my @recent_sizes;
    my @bestfit_sizes;

    for my $order_detail (
        $clothes->order_details->search(
            { 'me.status_id' => { '!='  => undef }, 'order.parent_id' => undef, },
            { order_by       => { -desc => 'id' },  join              => [qw/ order /], },
        )
        )
    {
        ++$rented_count;
        for (@measurements) {
            next unless $order_detail->order->$_;
            push @{ $average_size{$_} }, $order_detail->order->$_;
        }

        my %order_data = $order_detail->order->get_columns;
        my %size = map { $_ => $order_data{$_} } @measurements;
        $size{bestfit}  = $order_detail->order->bestfit;
        $size{order_id} = $order_detail->order_id;

        push @recent_sizes,  \%size if $rented_count <= 5;
        push @bestfit_sizes, \%size if $order_detail->order->bestfit;
    }
    for (@measurements) {
        if ( @{ $average_size{$_} } ) {
            $average_size{$_} = ( sum @{ $average_size{$_} } ) / @{ $average_size{$_} };
        }
        else {
            $average_size{$_} = 0;
        }
    }

    my @clothes_group = $clothes->donation->clothes(
        { code     => { '!=' => $clothes->code } },
        { order_by => 'category' }
    );
    my $code = $self->trim_clothes_code($clothes);
    my $suit;
    if ( my ($first) = $code =~ /^(J|P|K)/ ) { # Jacket, Pants, sKirt
        if ( $first eq 'J' ) {
            $suit = $clothes->suit_code_top;
        }
        else {
            $suit = $clothes->suit_code_bottom;
        }
    }

    #
    # response
    #
    $self->stash(
        average_size  => \%average_size,
        recent_sizes  => \@recent_sizes,
        bestfit_sizes => \@bestfit_sizes,
        clothes       => $clothes,
        clothes_group => \@clothes_group,
        suit          => $suit,
        rented_count  => $rented_count,
        tag_rs        => $self->DB->resultset('Tag'),
    );
}

=head2 clothes_pdf

    GET /clothes/:code/pdf

=cut

sub clothes_pdf {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ code /);

    my $clothes = $self->get_clothes( \%params );
    return unless $clothes;

    my $clothes_top;
    my $clothes_bottom;

    my $code = $self->trim_clothes_code($clothes);
    my $set_clothes;
    if ( my ($first) = $code =~ /^(J|P|K)/ ) { # Jacket, Pants, sKirt
        if ( $first eq 'J' ) {
            my $suit = $clothes->suit_code_top;
            $set_clothes = $suit->code_bottom if $suit;

            $clothes_top    = $clothes;
            $clothes_bottom = $set_clothes;
        }
        else {
            my $suit = $clothes->suit_code_bottom;
            $set_clothes = $suit->code_top if $suit;

            $clothes_top    = $set_clothes;
            $clothes_bottom = $clothes;
        }
    }

    my $color = $clothes->color;
    my $bust;
    my $topbelly;
    my $length_top;
    my $arm;
    my $waist;
    my $hip;
    my $thigh;
    my $length_bottom;
    my $cuff;

    if ($clothes_top) {
        $bust       = $clothes_top->bust;
        $topbelly   = $clothes_top->topbelly;
        $length_top = $clothes_top->length;
        $arm        = $clothes_top->arm;
    }

    if ($clothes_bottom) {
        $waist         = $clothes_bottom->waist;
        $hip           = $clothes_bottom->hip;
        $thigh         = $clothes_bottom->thigh;
        $length_bottom = $clothes_bottom->length;
        $cuff          = $clothes_bottom->cuff;
    }

    #
    # 의류 태그 PDF 출력시 코트와 원피스의 코드 및 사이즈 내역이 표기되지 않음 (#843)
    #
    {
        use experimental qw( smartmatch );

        if ( $clothes->category ~~ [ "onepiece", "coat" ] ) {
            $bust          = $clothes->bust;
            $topbelly      = $clothes->topbelly;
            $length_top    = $clothes->length;
            $arm           = $clothes->arm;
            $waist         = $clothes->waist;
            $hip           = $clothes->hip;
            $thigh         = $clothes->thigh;
            $length_bottom = $clothes->length;
            $cuff          = $clothes->cuff;

            $clothes_top = $clothes;
        }
    }

    $bust          ||= "-";
    $topbelly      ||= "-";
    $length_top    ||= "-";
    $arm           ||= "-";
    $waist         ||= "-";
    $hip           ||= "-";
    $thigh         ||= "-";
    $length_bottom ||= "-";
    $cuff          ||= "-";

    my @tags = map { $_->name } $clothes->tags;

    my $background_type;
    my $type_str = q{};
    {
        use experimental qw( smartmatch );

        if ( "온라인" ~~ @tags ) {
            if ( $clothes->gender eq "male" ) {
                $background_type = "online-male";
                $type_str        = "온라인 - 남성";
            }
            elsif ( $clothes->gender eq "female" ) {
                $background_type = "online-female";
                $type_str        = "온라인 - 여성";
            }
        }
        else {
            if ( $clothes->gender eq "male" ) {
                $background_type = "offline-male";
                $type_str        = "오프라인 - 남성";
            }
            elsif ( $clothes->gender eq "female" ) {
                $background_type = "offline-female";
                $type_str        = "오프라인 - 여성";
            }
        }

        if ( "하복" ~~ @tags ) {
            $background_type .= "-summer";
            $type_str        .= " - 하복";
        }
        elsif ( "동복" ~~ @tags ) {
            $background_type .= "-winter";
            $type_str        .= " - 동복";
        }
    }

    #
    # response
    #
    $self->stash(
        clothes         => $clothes,
        clothes_top     => $clothes_top,
        clothes_bottom  => $clothes_bottom,
        color           => $color,
        bust            => $bust,
        topbelly        => $topbelly,
        length_top      => $length_top,
        arm             => $arm,
        waist           => $waist,
        hip             => $hip,
        thigh           => $thigh,
        length_bottom   => $length_bottom,
        cuff            => $cuff,
        background_type => $background_type,
        type_str        => $type_str,
    );
}

1;

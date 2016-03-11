package OpenCloset::Web::Controller::Size;
use Mojo::Base 'Mojolicious::Controller';

use OpenCloset::Size::Guess;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 guess

    any /size/guess

=cut

sub guess {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ height weight gender /);

    my $height = $params{height};
    my $weight = $params{weight};
    my $gender = $params{gender};

    my $osg_db = OpenCloset::Size::Guess->new(
        'DB', _time_zone => $self->config->{timezone},
        _schema => $self->DB, _range => 0,
    );

    my $osg_bodykit = OpenCloset::Size::Guess->new(
        'BodyKit',
        _accessKey => $self->config->{bodykit}{accessKey},
        _secret    => $self->config->{bodykit}{secret},
    );

    my $bestfit_1_order_rs = $self->DB->resultset('Order')->search(
        { bestfit => 1, gender => $gender, height => $height, weight => $weight, },
        {
            order_by => [ { -asc => 'me.height' }, { -asc => 'me.weight' }, ],
            prefetch => { 'order_details' => 'clothes', },
        },
    );

    my $bestfit_3x3_order_rs = $self->DB->resultset('Order')->search(
        {
            bestfit => 1,
            gender  => $gender,
            height  => { -between => [ $height - 1, $height + 1, ], },
            weight  => { -between => [ $weight - 1, $weight + 1, ], },
        },
        {
            order_by => [ { -asc => 'me.height' }, { -asc => 'me.weight' }, ],
            prefetch => { 'order_details' => 'clothes', },
        },
    );

    $self->render(
        height               => $height,
        weight               => $weight,
        gender               => $gender,
        osg_bodykit          => $osg_bodykit,
        osg_db               => $osg_db,
        bestfit_1_order_rs   => $bestfit_1_order_rs,
        bestfit_3x3_order_rs => $bestfit_3x3_order_rs,
    );
}

1;

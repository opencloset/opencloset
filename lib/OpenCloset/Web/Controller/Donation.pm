package OpenCloset::Web::Controller::Donation;
use Mojo::Base 'Mojolicious::Controller';

use Data::Pageset;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 index

    GET /donation

=cut

sub index {
    my $self = shift;

    #
    # fetch params
    #
    my $p = $self->param('p') || 1;
    my $s = $self->param('s') || $self->config->{entries_per_page};
    my $q = $self->param('q');

    my $cond;
    my $join = [ { 'user' => 'user_info' } ];
    if ($q) {
        $cond = [
            { 'name'            => { like => "%$q%" } }, { 'email' => { like => "%$q%" } },
            { 'user_info.phone' => { like => "%$q%" } },
            { 'user_info.address4' => { like => "%$q%" } }, # 상세주소만 검색
            { 'user_info.birth' => { like => "%$q%" } }, { 'user_info.gender' => $q },
        ];

        if ( $q =~ m/^\w{4,5}$/ ) {
            push @$cond, { 'clothes.code' => sprintf( '%05s', uc($q) ) };
            $join = [ 'clothes', { 'user' => 'user_info' } ];
        }
    }
    else {
        $cond = {};
    }

    my $rs = $self->DB->resultset('Donation')->search(
        $cond,
        { join => $join, order_by => { -asc => 'id' }, page => $p, rows => $s },
    );

    my $bucket = $self->DB->resultset('Clothes')->search( { donation_id => undef } );

    my $pageset = Data::Pageset->new(
        {
            total_entries    => $rs->pager->total_entries,
            entries_per_page => $rs->pager->entries_per_page,
            pages_per_set    => 5,
            current_page     => $p,
        }
    );

    $self->stash(
        donation_list => $rs, bucket => $bucket, pageset => $pageset,
        q => $q || q{},
    );
}

=head2 donation

    GET /donation/:id

=cut

sub donation {
    my $self = shift;

    my $id = $self->param('id');
    my $donation = $self->DB->resultset('Donation')->find( { id => $id } );

    my $bucket = $self->DB->resultset('Clothes')->search( { donation_id => undef } );

    return $self->error( 404, { str => 'donation not found', data => {} } )
        unless $donation;

    $self->stash(
        donation     => $donation, bucket => $bucket,
        clothes_list => [ $donation->clothes ]
    );
}

1;

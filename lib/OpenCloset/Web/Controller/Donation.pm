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

    my ( $cond, $attr ) = $self->_search_cond_attr( $q, $p, $s );
    my $rs = $self->DB->resultset('Donation')->search( $cond, $attr );
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

=head2 _search_cond_attr($q, $page, $entries_per_page)

=cut

sub _search_cond_attr {
    my ( $self, $q, $page, $entries_per_page ) = @_;
    return ( undef, undef ) unless length $q > 1;

    my @or;
    my $join = { user => 'user_info' };
    if ( $q =~ /^[0-9\-]+$/ ) {
        $q =~ s/-//g;
        push @or, { 'user_info.phone' => { like => "%$q%" } };
        push @or, { email             => { like => "%$q%" } };
    }
    elsif ( $q =~ m/^0?[EBCJOPSAKTW][A-Z0-9]{3}$/ ) {
        push @or, { 'clothes.code' => sprintf( '%05s', uc($q) ) };
        $join = 'clothes';
    }
    elsif ( $q =~ /^[a-zA-Z0-9_\-]+/ ) {
        if ( $q =~ /\@/ ) {
            push @or, { email => { like => "%$q%" } };
        }
        else {
            push @or, { email => { like => "%$q%" } };
            push @or, { name  => { like => "%$q%" } };
        }
    }
    elsif ( $q =~ m/^[ㄱ-힣]+$/ ) {
        push @or, { name => { like => "%$q%" } };
    }

    my $attr = {
        join => $join, order_by => { -asc => 'id' }, page => $page,
        rows => $entries_per_page
    };

    return ( { -or => [@or] }, $attr );
}

1;

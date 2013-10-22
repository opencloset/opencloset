use utf8;
package Opencloset::Web::Schema::Result::DonorClothe;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Web::Schema::Result::DonorClothe

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Web::Schema::Base>

=cut

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'Opencloset::Web::Schema::Base';

=head1 TABLE: C<donor_clothes>

=cut

__PACKAGE__->table("donor_clothes");

=head1 ACCESSORS

=head2 donor_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 clothes_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 comment

  data_type: 'text'
  is_nullable: 1

=head2 donation_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "donor_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "clothes_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "donation_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</donor_id>

=item * L</clothes_id>

=back

=cut

__PACKAGE__->set_primary_key("donor_id", "clothes_id");

=head1 RELATIONS

=head2 clothe

Type: belongs_to

Related object: L<Opencloset::Web::Schema::Result::Clothe>

=cut

__PACKAGE__->belongs_to(
  "clothe",
  "Opencloset::Web::Schema::Result::Clothe",
  { id => "clothes_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);

=head2 donor

Type: belongs_to

Related object: L<Opencloset::Web::Schema::Result::Donor>

=cut

__PACKAGE__->belongs_to(
  "donor",
  "Opencloset::Web::Schema::Result::Donor",
  { id => "donor_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-10-23 04:06:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:It94cpBIutdGGFZzXsx2Wg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;

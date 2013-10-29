use utf8;
package Opencloset::Schema::Result::DonorClothe;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::DonorClothe

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<donor_clothe>

=cut

__PACKAGE__->table("donor_clothe");

=head1 ACCESSORS

=head2 donor_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 clothe_id

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
  "clothe_id",
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

=item * L</clothe_id>

=back

=cut

__PACKAGE__->set_primary_key("donor_id", "clothe_id");

=head1 RELATIONS

=head2 clothe

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Clothe>

=cut

__PACKAGE__->belongs_to(
  "clothe",
  "Opencloset::Schema::Result::Clothe",
  { id => "clothe_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);

=head2 donor

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Donor>

=cut

__PACKAGE__->belongs_to(
  "donor",
  "Opencloset::Schema::Result::Donor",
  { id => "donor_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-10-29 19:10:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gLVwDKZV0Mxy8GBI2i5aJQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

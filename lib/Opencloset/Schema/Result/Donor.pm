use utf8;
package Opencloset::Schema::Result::Donor;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::Donor

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<donor>

=cut

__PACKAGE__->table("donor");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 donation_msg

  data_type: 'text'
  is_nullable: 1

=head2 comment

  data_type: 'text'
  is_nullable: 1

=head2 create_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
  is_nullable: 1
  set_on_create: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "donation_msg",
  { data_type => "text", is_nullable => 1 },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "create_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime => 1,
    is_nullable => 1,
    set_on_create => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 

Type: belongs_to

Related object: L<Opencloset::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "",
  "Opencloset::Schema::Result::User",
  { id => "id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);

=head2 cloths

Type: has_many

Related object: L<Opencloset::Schema::Result::Cloth>

=cut

__PACKAGE__->has_many(
  "cloths",
  "Opencloset::Schema::Result::Cloth",
  { "foreign.donor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 donor_cloths

Type: has_many

Related object: L<Opencloset::Schema::Result::DonorCloth>

=cut

__PACKAGE__->has_many(
  "donor_cloths",
  "Opencloset::Schema::Result::DonorCloth",
  { "foreign.donor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-11-11 15:22:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tMb5tkoU7+WKISoLR1CZLg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

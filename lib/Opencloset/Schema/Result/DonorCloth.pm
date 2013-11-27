use utf8;
package Opencloset::Schema::Result::DonorCloth;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::DonorCloth

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<donor_cloth>

=cut

__PACKAGE__->table("donor_cloth");

=head1 ACCESSORS

=head2 user_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 cloth_id

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
  "user_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "cloth_id",
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

=item * L</user_id>

=item * L</cloth_id>

=back

=cut

__PACKAGE__->set_primary_key("user_id", "cloth_id");

=head1 RELATIONS

=head2 cloth

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Cloth>

=cut

__PACKAGE__->belongs_to(
  "cloth",
  "Opencloset::Schema::Result::Cloth",
  { id => "cloth_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);

=head2 user

Type: belongs_to

Related object: L<Opencloset::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "Opencloset::Schema::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07038 @ 2013-11-27 22:12:05
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oY4j0+Q60tqW3g65/GmLGA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

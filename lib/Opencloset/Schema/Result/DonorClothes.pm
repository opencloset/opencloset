use utf8;
package Opencloset::Schema::Result::DonorClothes;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::DonorClothes

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<donor_clothes>

=cut

__PACKAGE__->table("donor_clothes");

=head1 ACCESSORS

=head2 user_id

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
  "user_id",
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

=item * L</user_id>

=item * L</clothes_id>

=back

=cut

__PACKAGE__->set_primary_key("user_id", "clothes_id");

=head1 RELATIONS

=head2 clothes

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Clothes>

=cut

__PACKAGE__->belongs_to(
  "clothes",
  "Opencloset::Schema::Result::Clothes",
  { id => "clothes_id" },
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


# Created by DBIx::Class::Schema::Loader v0.07038 @ 2013-11-29 20:22:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jzp/66XLdXzt9AdvTZPZjg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

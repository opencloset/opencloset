use utf8;
package Opencloset::Schema::Result::OrderClothes;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::OrderClothes

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<order_clothes>

=cut

__PACKAGE__->table("order_clothes");

=head1 ACCESSORS

=head2 order_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 clothes_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "order_id",
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
);

=head1 PRIMARY KEY

=over 4

=item * L</order_id>

=item * L</clothes_id>

=back

=cut

__PACKAGE__->set_primary_key("order_id", "clothes_id");

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

=head2 order

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Order>

=cut

__PACKAGE__->belongs_to(
  "order",
  "Opencloset::Schema::Result::Order",
  { id => "order_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07038 @ 2013-11-29 20:22:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:947X1Qs3MDbYQMtyy8BG8A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

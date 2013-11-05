use utf8;
package Opencloset::Schema::Result::ClothOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::ClothOrder

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<cloth_order>

=cut

__PACKAGE__->table("cloth_order");

=head1 ACCESSORS

=head2 cloth_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 order_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "cloth_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "order_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</cloth_id>

=item * L</order_id>

=back

=cut

__PACKAGE__->set_primary_key("cloth_id", "order_id");

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


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-11-05 11:48:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:K1w9rbeiVq6AFBGlSer1PA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

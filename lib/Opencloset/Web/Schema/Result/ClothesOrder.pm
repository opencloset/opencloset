use utf8;
package Opencloset::Web::Schema::Result::ClothesOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Web::Schema::Result::ClothesOrder

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Web::Schema::Base>

=cut

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'Opencloset::Web::Schema::Base';

=head1 TABLE: C<clothes_order>

=cut

__PACKAGE__->table("clothes_order");

=head1 ACCESSORS

=head2 clothes_id

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
  "clothes_id",
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

=item * L</clothes_id>

=item * L</order_id>

=back

=cut

__PACKAGE__->set_primary_key("clothes_id", "order_id");

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

=head2 order

Type: belongs_to

Related object: L<Opencloset::Web::Schema::Result::Order>

=cut

__PACKAGE__->belongs_to(
  "order",
  "Opencloset::Web::Schema::Result::Order",
  { id => "order_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-10-23 04:06:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BL1gSzBfF3LKZ3MMmFgwcQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;

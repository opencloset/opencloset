use utf8;
package Opencloset::Schema::Result::Order;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::Order

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'Opencloset::Schema::Base';

=head1 TABLE: C<order>

=cut

__PACKAGE__->table("order");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 guest_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 rental_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
  is_nullable: 1

=head2 target_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
  is_nullable: 1

=head2 return_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
  is_nullable: 1

=head2 price

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 discount

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 comment

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "guest_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "rental_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime => 1,
    is_nullable => 1,
  },
  "target_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime => 1,
    is_nullable => 1,
  },
  "return_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime => 1,
    is_nullable => 1,
  },
  "price",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "discount",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "comment",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 clothes_orders

Type: has_many

Related object: L<Opencloset::Schema::Result::ClothesOrder>

=cut

__PACKAGE__->has_many(
  "clothes_orders",
  "Opencloset::Schema::Result::ClothesOrder",
  { "foreign.order_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 guest

Type: belongs_to

Related object: L<Opencloset::Schema::Result::Guest>

=cut

__PACKAGE__->belongs_to(
  "guest",
  "Opencloset::Schema::Result::Guest",
  { id => "guest_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);

=head2 clothes

Type: many_to_many

Composing rels: L</clothes_orders> -> clothe

=cut

__PACKAGE__->many_to_many("clothes", "clothes_orders", "clothe");


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-10-24 16:16:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yJHF5KUGAWnVY5tHfrA5IA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;

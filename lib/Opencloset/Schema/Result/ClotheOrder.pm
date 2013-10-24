use utf8;
package Opencloset::Schema::Result::ClotheOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::ClotheOrder

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'Opencloset::Schema::Base';

=head1 TABLE: C<clothe_order>

=cut

__PACKAGE__->table("clothe_order");

=head1 ACCESSORS

=head2 clothe_id

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
  "clothe_id",
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

=item * L</clothe_id>

=item * L</order_id>

=back

=cut

__PACKAGE__->set_primary_key("clothe_id", "order_id");

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


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-10-24 16:50:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:W9mb/49FNjugdAWdUEG+Yw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;

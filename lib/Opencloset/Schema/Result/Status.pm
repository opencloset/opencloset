use utf8;
package Opencloset::Schema::Result::Status;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::Status

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<status>

=cut

__PACKAGE__->table("status");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 64 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<name>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name", ["name"]);

=head1 RELATIONS

=head2 clothes

Type: has_many

Related object: L<Opencloset::Schema::Result::Clothes>

=cut

__PACKAGE__->has_many(
  "clothes",
  "Opencloset::Schema::Result::Clothes",
  { "foreign.status_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 order_details

Type: has_many

Related object: L<Opencloset::Schema::Result::OrderDetail>

=cut

__PACKAGE__->has_many(
  "order_details",
  "Opencloset::Schema::Result::OrderDetail",
  { "foreign.status_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 orders

Type: has_many

Related object: L<Opencloset::Schema::Result::Order>

=cut

__PACKAGE__->has_many(
  "orders",
  "Opencloset::Schema::Result::Order",
  { "foreign.status_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07038 @ 2013-12-26 15:12:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CseLC19xwLNgtbg6V/IpvQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

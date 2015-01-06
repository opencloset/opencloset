use utf8;
package OpenCloset::Schema::Result::Status;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

OpenCloset::Schema::Result::Status

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<OpenCloset::Schema::Base>

=cut

use base 'OpenCloset::Schema::Base';

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

Related object: L<OpenCloset::Schema::Result::Clothes>

=cut

__PACKAGE__->has_many(
  "clothes",
  "OpenCloset::Schema::Result::Clothes",
  { "foreign.status_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 order_details

Type: has_many

Related object: L<OpenCloset::Schema::Result::OrderDetail>

=cut

__PACKAGE__->has_many(
  "order_details",
  "OpenCloset::Schema::Result::OrderDetail",
  { "foreign.status_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 order_status_logs

Type: has_many

Related object: L<OpenCloset::Schema::Result::OrderStatusLog>

=cut

__PACKAGE__->has_many(
  "order_status_logs",
  "OpenCloset::Schema::Result::OrderStatusLog",
  { "foreign.status_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 orders

Type: has_many

Related object: L<OpenCloset::Schema::Result::Order>

=cut

__PACKAGE__->has_many(
  "orders",
  "OpenCloset::Schema::Result::Order",
  { "foreign.status_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-01-05 14:39:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hal2Tui8Ets0LPkE/ujaFA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

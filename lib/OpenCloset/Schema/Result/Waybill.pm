use utf8;
package OpenCloset::Schema::Result::Waybill;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

OpenCloset::Schema::Result::Waybill

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<OpenCloset::Schema::Base>

=cut

use base 'OpenCloset::Schema::Base';

=head1 TABLE: C<waybill>

=cut

__PACKAGE__->table("waybill");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 parcel_service_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 number

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "parcel_service_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "number",
  { data_type => "varchar", is_nullable => 1, size => 128 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 orders

Type: has_many

Related object: L<OpenCloset::Schema::Result::Order>

=cut

__PACKAGE__->has_many(
  "orders",
  "OpenCloset::Schema::Result::Order",
  { "foreign.waybill_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 parcel_service

Type: belongs_to

Related object: L<OpenCloset::Schema::Result::ParcelService>

=cut

__PACKAGE__->belongs_to(
  "parcel_service",
  "OpenCloset::Schema::Result::ParcelService",
  { id => "parcel_service_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-01-12 14:11:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ptmTw5Utq8Mj9fMGAavJuQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

use utf8;
package OpenCloset::Schema::Result::ParcelService;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

OpenCloset::Schema::Result::ParcelService

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<OpenCloset::Schema::Base>

=cut

use base 'OpenCloset::Schema::Base';

=head1 TABLE: C<parcel_service>

=cut

__PACKAGE__->table("parcel_service");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 tracking_url

  data_type: 'varchar'
  is_nullable: 1
  size: 512

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
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "tracking_url",
  { data_type => "varchar", is_nullable => 1, size => 512 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 waybills

Type: has_many

Related object: L<OpenCloset::Schema::Result::Waybill>

=cut

__PACKAGE__->has_many(
  "waybills",
  "OpenCloset::Schema::Result::Waybill",
  { "foreign.parcel_service_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-01-12 14:11:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:l7/jcMxlUVfCzrCQtxRMCA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

use utf8;
package Opencloset::Web::Schema::Result::Donor;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Web::Schema::Result::Donor

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Web::Schema::Base>

=cut

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'Opencloset::Web::Schema::Base';

=head1 TABLE: C<donor>

=cut

__PACKAGE__->table("donor");

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
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 donor_clothes

Type: has_many

Related object: L<Opencloset::Web::Schema::Result::DonorClothe>

=cut

__PACKAGE__->has_many(
  "donor_clothes",
  "Opencloset::Web::Schema::Result::DonorClothe",
  { "foreign.donor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-10-23 04:06:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bmuc1DHHPY6rG6DPqSk9Xg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;

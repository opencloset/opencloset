use utf8;
package Postcodify::Schema::Result::PostcodifyRoad;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Postcodify::Schema::Result::PostcodifyRoad

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Postcodify::Schema::Base>

=cut

use base 'Postcodify::Schema::Base';

=head1 TABLE: C<postcodify_roads>

=cut

__PACKAGE__->table("postcodify_roads");

=head1 ACCESSORS

=head2 road_id

  data_type: 'numeric'
  is_nullable: 0
  size: 14

=head2 road_name_ko

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 road_name_en

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 sido_ko

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 sido_en

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 sigungu_ko

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 sigungu_en

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 ilbangu_ko

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 ilbangu_en

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 eupmyeon_ko

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 eupmyeon_en

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=cut

__PACKAGE__->add_columns(
  "road_id",
  { data_type => "numeric", is_nullable => 0, size => 14 },
  "road_name_ko",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "road_name_en",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "sido_ko",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "sido_en",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "sigungu_ko",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "sigungu_en",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "ilbangu_ko",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "ilbangu_en",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "eupmyeon_ko",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "eupmyeon_en",
  { data_type => "varchar", is_nullable => 1, size => 40 },
);

=head1 PRIMARY KEY

=over 4

=item * L</road_id>

=back

=cut

__PACKAGE__->set_primary_key("road_id");


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2014-11-20 04:57:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hkwhBEATQu4GNC0oNtXo+g

__PACKAGE__->has_many(
  "addresses",
  "Postcodify::Schema::Result::PostcodifyAddress",
  { "foreign.road_id" => "self.road_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

1;

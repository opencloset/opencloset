use utf8;
package Postcodify::Schema::Result::PostcodifyEnglish;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Postcodify::Schema::Result::PostcodifyEnglish

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Postcodify::Schema::Base>

=cut

use base 'Postcodify::Schema::Base';

=head1 TABLE: C<postcodify_english>

=cut

__PACKAGE__->table("postcodify_english");

=head1 ACCESSORS

=head2 seq

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 ko

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 ko_crc32

  data_type: 'integer'
  is_nullable: 1
  size: 10

=head2 en

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 en_crc32

  data_type: 'integer'
  is_nullable: 1
  size: 10

=cut

__PACKAGE__->add_columns(
  "seq",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "ko",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "ko_crc32",
  { data_type => "integer", is_nullable => 1, size => 10 },
  "en",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "en_crc32",
  { data_type => "integer", is_nullable => 1, size => 10 },
);

=head1 PRIMARY KEY

=over 4

=item * L</seq>

=back

=cut

__PACKAGE__->set_primary_key("seq");


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2014-11-20 04:57:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:49E7feB69Lh504SWSaoD8g

__PACKAGE__->belongs_to(
  "keyword",
  "Postcodify::Schema::Result::PostcodifyKeyword",
  { ko_crc32 => "keyword_crc32" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

1;

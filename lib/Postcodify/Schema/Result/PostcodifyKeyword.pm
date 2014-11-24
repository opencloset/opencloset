use utf8;
package Postcodify::Schema::Result::PostcodifyKeyword;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Postcodify::Schema::Result::PostcodifyKeyword

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Postcodify::Schema::Base>

=cut

use base 'Postcodify::Schema::Base';

=head1 TABLE: C<postcodify_keywords>

=cut

__PACKAGE__->table("postcodify_keywords");

=head1 ACCESSORS

=head2 seq

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 address_id

  data_type: 'integer'
  is_nullable: 0

=head2 keyword_crc32

  data_type: 'integer'
  is_nullable: 1
  size: 10

=cut

__PACKAGE__->add_columns(
  "seq",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "address_id",
  { data_type => "integer", is_nullable => 0 },
  "keyword_crc32",
  { data_type => "integer", is_nullable => 1, size => 10 },
);

=head1 PRIMARY KEY

=over 4

=item * L</seq>

=back

=cut

__PACKAGE__->set_primary_key("seq");


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2014-11-20 04:57:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ewLC+Z7U/cLF723vd9ue6Q

__PACKAGE__->belongs_to(
  "address",
  "Postcodify::Schema::Result::PostcodifyAddress",
  { address_id => "id" },
  {
    is_deferrable => 0,
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

__PACKAGE__->has_many(
  "english",
  "Postcodify::Schema::Result::PostcodifyEnglish",
  { "foreign.ko_crc32" => "self.keyword_crc32" },
  { cascade_copy => 0, cascade_delete => 0 },
);

1;

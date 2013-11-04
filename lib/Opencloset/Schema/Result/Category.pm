use utf8;
package Opencloset::Schema::Result::Category;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::Category

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<category>

=cut

__PACKAGE__->table("category");

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

=head2 price

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 which

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 abbr

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
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "price",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "which",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "abbr",
  { data_type => "varchar", is_nullable => 0, size => 32 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<abbr>

=over 4

=item * L</abbr>

=back

=cut

__PACKAGE__->add_unique_constraint("abbr", ["abbr"]);

=head2 C<name>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name", ["name"]);

=head1 RELATIONS

=head2 clothes

Type: has_many

Related object: L<Opencloset::Schema::Result::Clothe>

=cut

__PACKAGE__->has_many(
  "clothes",
  "Opencloset::Schema::Result::Clothe",
  { "foreign.category_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-11-04 15:16:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:VFv7ugJ5WA3+jYIqJHIdPw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

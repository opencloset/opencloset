use utf8;
package Opencloset::Schema::Result::Userinfo;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::Userinfo

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<userinfo>

=cut

__PACKAGE__->table("userinfo");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 phone

  data_type: 'varchar'
  is_nullable: 1
  size: 16

regex: 01d{8,9}

=head2 address

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 gender

  data_type: 'varchar'
  is_nullable: 1
  size: 6

male/female

=head2 birth

  data_type: 'tinyint'
  is_nullable: 1

=head2 comment

  data_type: 'text'
  is_nullable: 1

=head2 height

  data_type: 'integer'
  is_nullable: 1

=head2 weight

  data_type: 'integer'
  is_nullable: 1

=head2 bust

  data_type: 'integer'
  is_nullable: 1

=head2 waist

  data_type: 'integer'
  is_nullable: 1

=head2 hip

  data_type: 'integer'
  is_nullable: 1

=head2 thigh

  data_type: 'integer'
  is_nullable: 1

=head2 arm

  data_type: 'integer'
  is_nullable: 1

=head2 leg

  data_type: 'integer'
  is_nullable: 1

=head2 knee

  data_type: 'integer'
  is_nullable: 1

=head2 foot

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "user_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "phone",
  { data_type => "varchar", is_nullable => 1, size => 16 },
  "address",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "gender",
  { data_type => "varchar", is_nullable => 1, size => 6 },
  "birth",
  { data_type => "tinyint", is_nullable => 1 },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "height",
  { data_type => "integer", is_nullable => 1 },
  "weight",
  { data_type => "integer", is_nullable => 1 },
  "bust",
  { data_type => "integer", is_nullable => 1 },
  "waist",
  { data_type => "integer", is_nullable => 1 },
  "hip",
  { data_type => "integer", is_nullable => 1 },
  "thigh",
  { data_type => "integer", is_nullable => 1 },
  "arm",
  { data_type => "integer", is_nullable => 1 },
  "leg",
  { data_type => "integer", is_nullable => 1 },
  "knee",
  { data_type => "integer", is_nullable => 1 },
  "foot",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<phone>

=over 4

=item * L</phone>

=back

=cut

__PACKAGE__->add_unique_constraint("phone", ["phone"]);

=head2 C<user_id>

=over 4

=item * L</user_id>

=back

=cut

__PACKAGE__->add_unique_constraint("user_id", ["user_id"]);

=head1 RELATIONS

=head2 user

Type: belongs_to

Related object: L<Opencloset::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "Opencloset::Schema::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07038 @ 2013-11-27 22:12:05
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9kqiD/X3mHp+lTH9w8eRww


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

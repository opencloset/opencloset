use utf8;
package Opencloset::Schema::Result::Donor;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::Donor

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

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

=head2 email

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 phone

  data_type: 'varchar'
  is_nullable: 1
  size: 16

regex: [0-9]{10,11}

=head2 gender

  data_type: 'integer'
  is_nullable: 1

1: male, 2: female

=head2 address

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 message

  data_type: 'text'
  is_nullable: 1

=head2 comment

  data_type: 'text'
  is_nullable: 1

=head2 create_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
  is_nullable: 1
  set_on_create: 1

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
  "email",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "phone",
  { data_type => "varchar", is_nullable => 1, size => 16 },
  "gender",
  { data_type => "integer", is_nullable => 1 },
  "address",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "message",
  { data_type => "text", is_nullable => 1 },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "create_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime => 1,
    is_nullable => 1,
    set_on_create => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<email>

=over 4

=item * L</email>

=back

=cut

__PACKAGE__->add_unique_constraint("email", ["email"]);

=head2 C<phone>

=over 4

=item * L</phone>

=back

=cut

__PACKAGE__->add_unique_constraint("phone", ["phone"]);

=head1 RELATIONS

=head2 cloths

Type: has_many

Related object: L<Opencloset::Schema::Result::Cloth>

=cut

__PACKAGE__->has_many(
  "cloths",
  "Opencloset::Schema::Result::Cloth",
  { "foreign.donor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 donor_cloths

Type: has_many

Related object: L<Opencloset::Schema::Result::DonorCloth>

=cut

__PACKAGE__->has_many(
  "donor_cloths",
  "Opencloset::Schema::Result::DonorCloth",
  { "foreign.donor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-11-05 11:48:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wTZsR8WK4j+mp82+j5pgkQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

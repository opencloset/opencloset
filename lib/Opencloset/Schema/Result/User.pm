use utf8;
package Opencloset::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::User

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<user>

=cut

__PACKAGE__->table("user");

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

=head2 password

  data_type: 'char'
  encode_args: {algorithm => "SHA-1",format => "hex",salt_length => 10}
  encode_check_method: 'check_password'
  encode_class: 'Digest'
  encode_column: 1
  is_nullable: 1
  size: 50

first 40 length for digest, after 10 length for salt(random)

=head2 phone

  data_type: 'varchar'
  is_nullable: 1
  size: 16

regex: 01d{8,9}

=head2 gender

  data_type: 'integer'
  is_nullable: 1

1: male, 2: female

=head2 age

  data_type: 'integer'
  is_nullable: 1

=head2 address

  data_type: 'varchar'
  is_nullable: 1
  size: 255

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
  "password",
  {
    data_type           => "char",
    encode_args         => { algorithm => "SHA-1", format => "hex", salt_length => 10 },
    encode_check_method => "check_password",
    encode_class        => "Digest",
    encode_column       => 1,
    is_nullable         => 1,
    size                => 50,
  },
  "phone",
  { data_type => "varchar", is_nullable => 1, size => 16 },
  "gender",
  { data_type => "integer", is_nullable => 1 },
  "age",
  { data_type => "integer", is_nullable => 1 },
  "address",
  { data_type => "varchar", is_nullable => 1, size => 255 },
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

=head2 donors

Type: has_many

Related object: L<Opencloset::Schema::Result::Donor>

=cut

__PACKAGE__->has_many(
  "donors",
  "Opencloset::Schema::Result::Donor",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 guests

Type: has_many

Related object: L<Opencloset::Schema::Result::Guest>

=cut

__PACKAGE__->has_many(
  "guests",
  "Opencloset::Schema::Result::Guest",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-11-12 10:51:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RAZnsfpqTtn0uHxu5P7hRA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

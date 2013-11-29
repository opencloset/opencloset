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

=head1 RELATIONS

=head2 clothes

Type: has_many

Related object: L<Opencloset::Schema::Result::Clothes>

=cut

__PACKAGE__->has_many(
  "clothes",
  "Opencloset::Schema::Result::Clothes",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 donor_clothes

Type: has_many

Related object: L<Opencloset::Schema::Result::DonorClothes>

=cut

__PACKAGE__->has_many(
  "donor_clothes",
  "Opencloset::Schema::Result::DonorClothes",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 orders

Type: has_many

Related object: L<Opencloset::Schema::Result::Order>

=cut

__PACKAGE__->has_many(
  "orders",
  "Opencloset::Schema::Result::Order",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 satisfactions

Type: has_many

Related object: L<Opencloset::Schema::Result::Satisfaction>

=cut

__PACKAGE__->has_many(
  "satisfactions",
  "Opencloset::Schema::Result::Satisfaction",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_info

Type: might_have

Related object: L<Opencloset::Schema::Result::UserInfo>

=cut

__PACKAGE__->might_have(
  "user_info",
  "Opencloset::Schema::Result::UserInfo",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07038 @ 2013-11-29 20:22:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fW7DSOTGRAiwwZndxEkWcw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

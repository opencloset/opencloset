use utf8;
package OpenCloset::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

OpenCloset::Schema::Result::User

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<OpenCloset::Schema::Base>

=cut

use base 'OpenCloset::Schema::Base';

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

=head2 expires

  data_type: 'integer'
  is_nullable: 1

=head2 create_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
  is_nullable: 1
  set_on_create: 1

=head2 update_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
  is_nullable: 1
  set_on_create: 1
  set_on_update: 1

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
  "expires",
  { data_type => "integer", is_nullable => 1 },
  "create_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime => 1,
    is_nullable => 1,
    set_on_create => 1,
  },
  "update_date",
  {
    data_type                 => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime          => 1,
    is_nullable               => 1,
    set_on_create             => 1,
    set_on_update             => 1,
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

=head2 donations

Type: has_many

Related object: L<OpenCloset::Schema::Result::Donation>

=cut

__PACKAGE__->has_many(
  "donations",
  "OpenCloset::Schema::Result::Donation",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 order_staffs

Type: has_many

Related object: L<OpenCloset::Schema::Result::Order>

=cut

__PACKAGE__->has_many(
  "order_staffs",
  "OpenCloset::Schema::Result::Order",
  { "foreign.staff_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 order_users

Type: has_many

Related object: L<OpenCloset::Schema::Result::Order>

=cut

__PACKAGE__->has_many(
  "order_users",
  "OpenCloset::Schema::Result::Order",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 satisfactions

Type: has_many

Related object: L<OpenCloset::Schema::Result::Satisfaction>

=cut

__PACKAGE__->has_many(
  "satisfactions",
  "OpenCloset::Schema::Result::Satisfaction",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_bookings

Type: has_many

Related object: L<OpenCloset::Schema::Result::UserBooking>

=cut

__PACKAGE__->has_many(
  "user_bookings",
  "OpenCloset::Schema::Result::UserBooking",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user_info

Type: might_have

Related object: L<OpenCloset::Schema::Result::UserInfo>

=cut

__PACKAGE__->might_have(
  "user_info",
  "OpenCloset::Schema::Result::UserInfo",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2014-08-28 16:11:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KmEbL8mfXXueQ1XRmL4heQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

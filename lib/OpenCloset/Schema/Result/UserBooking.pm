use utf8;
package OpenCloset::Schema::Result::UserBooking;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

OpenCloset::Schema::Result::UserBooking

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<OpenCloset::Schema::Base>

=cut

use base 'OpenCloset::Schema::Base';

=head1 TABLE: C<user_booking>

=cut

__PACKAGE__->table("user_booking");

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

=head2 booking_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

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
  "booking_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<user_id>

=over 4

=item * L</user_id>

=item * L</booking_id>

=back

=cut

__PACKAGE__->add_unique_constraint("user_id", ["user_id", "booking_id"]);

=head1 RELATIONS

=head2 booking

Type: belongs_to

Related object: L<OpenCloset::Schema::Result::Booking>

=cut

__PACKAGE__->belongs_to(
  "booking",
  "OpenCloset::Schema::Result::Booking",
  { id => "booking_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);

=head2 user

Type: belongs_to

Related object: L<OpenCloset::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "OpenCloset::Schema::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2014-09-25 18:18:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Yr6nIogsIpZxycXn7jCBMg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

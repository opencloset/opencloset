use utf8;
package OpenCloset::Schema::Result::Booking;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

OpenCloset::Schema::Result::Booking

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<OpenCloset::Schema::Base>

=cut

use base 'OpenCloset::Schema::Base';

=head1 TABLE: C<booking>

=cut

__PACKAGE__->table("booking");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
  is_nullable: 0

=head2 gender

  data_type: 'varchar'
  is_nullable: 0
  size: 6

male/female

=head2 slot

  data_type: 'integer'
  extra: {unsigned => 1}
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
  "date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime => 1,
    is_nullable => 0,
  },
  "gender",
  { data_type => "varchar", is_nullable => 0, size => 6 },
  "slot",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<date>

=over 4

=item * L</date>

=item * L</gender>

=back

=cut

__PACKAGE__->add_unique_constraint("date", ["date", "gender"]);

=head1 RELATIONS

=head2 user_bookings

Type: has_many

Related object: L<OpenCloset::Schema::Result::UserBooking>

=cut

__PACKAGE__->has_many(
  "user_bookings",
  "OpenCloset::Schema::Result::UserBooking",
  { "foreign.booking_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2014-08-28 16:11:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cYuyr5WrQ1PNGZol1mJB3Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration

=head2 users

Type: many_to_many

Related object: L<OpenCloset::Schema::Result::User>

=cut

__PACKAGE__->many_to_many( "users", "user_bookings", "user" );

=head1 Additional ACCESSORS

=head2 user_count

https://metacpan.org/pod/DBIx::Class::Manual::Cookbook#Using-database-functions-or-stored-procedures
https://metacpan.org/pod/DBIx::Class::Manual::Cookbook#Using-SQL-functions-on-the-left-hand-side-of-a-comparison

=cut

__PACKAGE__->mk_group_accessors( column => 'user_count' );

1;

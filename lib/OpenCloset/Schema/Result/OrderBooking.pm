use utf8;
package OpenCloset::Schema::Result::OrderBooking;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

OpenCloset::Schema::Result::OrderBooking

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<OpenCloset::Schema::Base>

=cut

use base 'OpenCloset::Schema::Base';

=head1 TABLE: C<order_booking>

=cut

__PACKAGE__->table("order_booking");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 order_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 booking_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

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
  "order_id",
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

=head2 C<order_id>

=over 4

=item * L</order_id>

=item * L</booking_id>

=back

=cut

__PACKAGE__->add_unique_constraint("order_id", ["order_id", "booking_id"]);

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

=head2 order

Type: belongs_to

Related object: L<OpenCloset::Schema::Result::Order>

=cut

__PACKAGE__->belongs_to(
  "order",
  "OpenCloset::Schema::Result::Order",
  { id => "order_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2014-10-24 17:11:00
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mfAD97CAv/S2SBpetIUW7g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

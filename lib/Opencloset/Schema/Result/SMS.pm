use utf8;
package Opencloset::Schema::Result::SMS;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::SMS

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<sms>

=cut

__PACKAGE__->table("sms");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 from

  data_type: 'varchar'
  is_nullable: 0
  size: 12

=head2 to

  data_type: 'varchar'
  is_nullable: 0
  size: 12

=head2 text

  data_type: 'varchar'
  is_nullable: 0
  size: 256

=head2 ret

  data_type: 'integer'
  is_nullable: 1

=head2 status

  data_type: 'varchar'
  default_value: 'pending'
  is_nullable: 1
  size: 7

=head2 sent_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
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
  "from",
  { data_type => "varchar", is_nullable => 0, size => 12 },
  "to",
  { data_type => "varchar", is_nullable => 0, size => 12 },
  "text",
  { data_type => "varchar", is_nullable => 0, size => 256 },
  "ret",
  { data_type => "integer", is_nullable => 1 },
  "status",
  {
    data_type => "varchar",
    default_value => "pending",
    is_nullable => 1,
    size => 7,
  },
  "sent_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime => 1,
    is_nullable => 1,
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


# Created by DBIx::Class::Schema::Loader v0.07038 @ 2014-01-23 15:13:10
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WfiDeeejTZweg+VegxsTpA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

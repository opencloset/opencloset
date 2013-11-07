use utf8;
package Opencloset::Schema::Result::ShortMessage;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Opencloset::Schema::Result::ShortMessage

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Opencloset::Schema::Base>

=cut

use base 'Opencloset::Schema::Base';

=head1 TABLE: C<short_message>

=cut

__PACKAGE__->table("short_message");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 from

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 to

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 msg

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 sent_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
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
  "from",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "to",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "msg",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "sent_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    inflate_datetime => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-11-07 14:58:46
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sje9N4URg3wCv4HGfPAG+w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

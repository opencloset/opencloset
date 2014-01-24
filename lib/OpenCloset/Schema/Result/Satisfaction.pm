use utf8;
package OpenCloset::Schema::Result::Satisfaction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

OpenCloset::Schema::Result::Satisfaction

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<OpenCloset::Schema::Base>

=cut

use base 'OpenCloset::Schema::Base';

=head1 TABLE: C<satisfaction>

=cut

__PACKAGE__->table("satisfaction");

=head1 ACCESSORS

=head2 user_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 clothes_code

  data_type: 'char'
  is_foreign_key: 1
  is_nullable: 0
  size: 5

=head2 bust

  data_type: 'integer'
  is_nullable: 1

=head2 waist

  data_type: 'integer'
  is_nullable: 1

=head2 arm

  data_type: 'integer'
  is_nullable: 1

=head2 top_fit

  data_type: 'integer'
  is_nullable: 1

=head2 bottom_fit

  data_type: 'integer'
  is_nullable: 1

=head2 create_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  inflate_datetime: 1
  is_nullable: 1
  set_on_create: 1

=cut

__PACKAGE__->add_columns(
  "user_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "clothes_code",
  { data_type => "char", is_foreign_key => 1, is_nullable => 0, size => 5 },
  "bust",
  { data_type => "integer", is_nullable => 1 },
  "waist",
  { data_type => "integer", is_nullable => 1 },
  "arm",
  { data_type => "integer", is_nullable => 1 },
  "top_fit",
  { data_type => "integer", is_nullable => 1 },
  "bottom_fit",
  { data_type => "integer", is_nullable => 1 },
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

=item * L</user_id>

=item * L</clothes_code>

=back

=cut

__PACKAGE__->set_primary_key("user_id", "clothes_code");

=head1 RELATIONS

=head2 clothes

Type: belongs_to

Related object: L<OpenCloset::Schema::Result::Clothes>

=cut

__PACKAGE__->belongs_to(
  "clothes",
  "OpenCloset::Schema::Result::Clothes",
  { code => "clothes_code" },
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


# Created by DBIx::Class::Schema::Loader v0.07038 @ 2014-01-24 15:02:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AC8KFpMynP3smG1bbIF1uA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

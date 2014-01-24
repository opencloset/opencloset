use utf8;
package OpenCloset::Schema::Result::OrderDetail;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

OpenCloset::Schema::Result::OrderDetail

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<OpenCloset::Schema::Base>

=cut

use base 'OpenCloset::Schema::Base';

=head1 TABLE: C<order_detail>

=cut

__PACKAGE__->table("order_detail");

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

=head2 clothes_code

  data_type: 'char'
  is_foreign_key: 1
  is_nullable: 1
  size: 5

=head2 status_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 1

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 price

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 final_price

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 stage

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 desc

  data_type: 'text'
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
  "order_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "clothes_code",
  { data_type => "char", is_foreign_key => 1, is_nullable => 1, size => 5 },
  "status_id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 1,
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "price",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "final_price",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "stage",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "desc",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 clothes

Type: belongs_to

Related object: L<OpenCloset::Schema::Result::Clothes>

=cut

__PACKAGE__->belongs_to(
  "clothes",
  "OpenCloset::Schema::Result::Clothes",
  { code => "clothes_code" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "RESTRICT",
  },
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

=head2 status

Type: belongs_to

Related object: L<OpenCloset::Schema::Result::Status>

=cut

__PACKAGE__->belongs_to(
  "status",
  "OpenCloset::Schema::Result::Status",
  { id => "status_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "RESTRICT",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07038 @ 2014-01-24 15:02:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:paQexXCFv821+1oT2D0aMA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

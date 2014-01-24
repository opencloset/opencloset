use utf8;
package OpenCloset::Schema::Result::Group;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

OpenCloset::Schema::Result::Group

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<OpenCloset::Schema::Base>

=cut

use base 'OpenCloset::Schema::Base';

=head1 TABLE: C<group>

=cut

__PACKAGE__->table("group");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
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
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 clothes

Type: has_many

Related object: L<OpenCloset::Schema::Result::Clothes>

=cut

__PACKAGE__->has_many(
  "clothes",
  "OpenCloset::Schema::Result::Clothes",
  { "foreign.group_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07038 @ 2014-01-24 15:02:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bWTM0Ng/JwlEnn4HfS7Nsg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

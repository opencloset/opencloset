use utf8;
package Postcodify::Schema::Result::PostcodifySetting;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Postcodify::Schema::Result::PostcodifySetting

=cut

use strict;
use warnings;

=head1 BASE CLASS: L<Postcodify::Schema::Base>

=cut

use base 'Postcodify::Schema::Base';

=head1 TABLE: C<postcodify_settings>

=cut

__PACKAGE__->table("postcodify_settings");

=head1 ACCESSORS

=head2 k

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 v

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=cut

__PACKAGE__->add_columns(
  "k",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "v",
  { data_type => "varchar", is_nullable => 1, size => 40 },
);

=head1 PRIMARY KEY

=over 4

=item * L</k>

=back

=cut

__PACKAGE__->set_primary_key("k");


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2014-11-20 04:57:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kTqA2s4ietYq8MpEJO0I4g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;

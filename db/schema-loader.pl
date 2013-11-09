use strict;
use warnings;

use Path::Tiny;

#
# load from app.conf
#
my $conf_file = 'app.conf';
die "cannot find config file" unless -e $conf_file;
my $conf = eval path($conf_file)->slurp_utf8;

{
    schema_class => "Opencloset::Schema",
    connect_info => {
        dsn  => $conf->{database}{dsn},
        user => $conf->{database}{user},
        pass => $conf->{database}{pass},
        %{ $conf->{database}{opts} },
    },
    loader_options => {
        dump_directory            => 'lib',
        naming                    => { ALL => 'v8' },
        skip_load_external        => 1,
        relationships             => 1,
        col_collision_map         => 'column_%s',
        result_base_class         => 'Opencloset::Schema::Base',
        overwrite_modifications   => 1,
        datetime_undef_if_invalid => 1,
        custom_column_info        => sub {
            my ($table, $col_name, $col_info) = @_;
            if ($col_name eq 'create_date') {
                return {%{$col_info}, set_on_create => 1, inflate_datetime => 1};
            }
            elsif ($col_name eq 'visit_date') {
                return {%{$col_info}, set_on_create => 1, set_on_update => 1, inflate_datetime => 1};
            }
            elsif ($col_name =~ /_date$/) {
                return {%{$col_info}, inflate_datetime => 1};
            }

            if ($col_name eq 'password') {
                return {
                    %{$col_info},
                    encode_column => 1,
                    encode_class  => 'Digest',
                    encode_args   => { algorithm => 'SHA-1', format => 'hex', salt_length => 10 },
                    encode_check_method => 'check_password',
                };
            }
        }
    },
}

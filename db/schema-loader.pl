my $DB_NAME     = $ENV{OPENCLOSET_DB}       || 'opencloset';
my $DB_USERNAME = $ENV{OPENCLOSET_USERNAME} || 'root';
my $DB_PASSWORD = $ENV{OPENCLOSET_PASSWORD} || '';

{
    schema_class => "Opencloset::Web::Schema",
    connect_info => {
        dsn               => "dbi:mysql:$DB_NAME:127.0.0.1",
        user              => $DB_USERNAME,
        pass              => $DB_PASSWORD,
        mysql_enable_utf8 => 1,
    },
    loader_options => {
        dump_directory            => 'lib',
        naming                    => { ALL => 'v8' },
        skip_load_external        => 1,
        relationships             => 1,
        use_moose                 => 1,
        only_autoclean            => 1,
        col_collision_map         => 'column_%s',
        result_base_class         => 'Opencloset::Web::Schema::Base',
        overwrite_modifications   => 1,
        datetime_undef_if_invalid => 1,
        custom_column_info        => sub {
            my ($table, $col_name, $col_info) = @_;
            if ($col_name =~ /_date$/) {
                # set_on_create => 1, 
                return {%{$col_info}, inflate_datetime => 1};
            }
        }
    },
}

requires 'Data::Pageset';
requires 'DateTime';
requires 'DateTime::Format::Duration';
requires 'DateTime::Format::Human::Duration', '0.62';
requires 'FindBin';
requires 'Getopt::Long::Descriptive';
requires 'Gravatar::URL';
requires 'HTTP::Tiny';
requires 'JSON';
requires 'List::MoreUtils';
requires 'List::Util';
requires 'Mojolicious','5.48';
requires 'Mojolicious::Plugin::Authentication';
requires 'Mojolicious::Plugin::FillInFormLite';
requires 'Mojolicious::Plugin::HamlRenderer';
requires 'Mojolicious::Plugin::Validator';
requires 'Parcel::Track', '0.005';
requires 'Parcel::Track::KR::CJKorea';
requires 'Parcel::Track::KR::Dongbu';
requires 'Parcel::Track::KR::Hanjin';
requires 'Parcel::Track::KR::KGB';
requires 'Parcel::Track::KR::PostOffice';
requires 'Parcel::Track::KR::Yellowcap';
requires 'Path::Tiny';
requires 'SMS::Send::KR::APIStore', '0.001';
requires 'SMS::Send::KR::CoolSMS', '1.003';
requires 'Scalar::Util';
requires 'Statistics::Basic';
requires 'Text::CSV';
requires 'Text::Haml', '0.990114';
requires 'Try::Tiny';
requires 'Unicode::GCString';
requires 'experimental';

# from git repository
requires 'git://github.com/aanoaa/p5-postcodify.git@v0.2.6';

# from opencloset cpan
requires 'OpenCloset::Config',               '0.002';
requires 'OpenCloset::Schema',               '0.015';
requires 'OpenCloset::Size::Guess',          '0.003';
requires 'OpenCloset::Size::Guess::BodyKit', '0.001';
requires 'OpenCloset::Size::Guess::DB',      '0.005';

package OpenCloset::Web;
use Mojo::Base 'Mojolicious';

use CHI;
use DateTime;

use OpenCloset::Schema;
use version; our $VERSION = qv("v1.8.10");
has CACHE => sub {
    my $self  = shift;
    my $cache = CHI->new(
        driver   => 'File',
        root_dir => $self->config->{cache}{dir} || './cache'
    );
    $self->log->info( "cache dir: " . $cache->root_dir );

    return $cache;
};

has DB => sub {
    my $self = shift;
    my $conf = $self->config->{database};

    return OpenCloset::Schema->connect(
        {
            dsn      => $conf->{dsn},
            user     => $conf->{user},
            password => $conf->{pass},
            %{ $conf->{opts} },
        }
    );
};

=head1 METHODS

=head2 startup

This method will run once at server start

=cut

sub startup {
    my $self = shift;

    $self->defaults(
        jses        => [],
        csses       => [],
        breadcrumbs => [],
        active_id   => q{},
        page_id     => q{},
        alert       => q{},
        type        => q{},
        %{ $self->plugin('Config') }
    );

    $self->plugin('validator');
    $self->plugin('haml_renderer');
    $self->plugin('OpenCloset::Plugin::Helpers');
    $self->plugin('OpenCloset::Web::Plugin::Helpers');

    $self->_authentication;
    $self->_public_routes;
    $self->_private_routes;
    $self->_2depth_private_routes;

    $self->secrets( $self->defaults->{secrets} );
    $self->sessions->cookie_domain( $self->defaults->{cookie_domain} );
    $self->sessions->cookie_name('opencloset');
    $self->sessions->default_expiration(86400);
}

=head2 _authentication

=cut

sub _authentication {
    my $self = shift;

    $self->plugin(
        'authentication' => {
            autoload_user => 1,
            load_user     => sub {
                my ( $app, $uid ) = @_;

                my $user_obj = $self->DB->resultset('User')->find( { id => $uid } );

                return $user_obj;
            },
            session_key   => 'access_token',
            validate_user => sub {
                my ( $self, $user, $pass, $extradata ) = @_;

                my $user_obj = $self->DB->resultset('User')->find( { email => $user } );
                unless ($user_obj) {
                    $self->log->warn("cannot find such user: $user");
                    return;
                }

                #
                # GitHub #199
                #
                # check expires when login
                #
                my $now = DateTime->now( time_zone => $self->config->{timezone} )->epoch;
                unless ( $user_obj->expires && $user_obj->expires > $now ) {
                    $self->log->warn("$user\'s password is expired");
                    return;
                }

                unless ( $user_obj->check_password($pass) ) {
                    $self->log->warn("$user\'s password is wrong");
                    return;
                }

                unless ( $user_obj->user_info->staff ) {
                    $self->log->warn("$user is not a staff");
                    return;
                }

                return $user_obj->id;
            },
        }
    );
}

=head2 _public_routes

=cut

sub _public_routes {
    my $self = shift;
    my $r    = $self->routes;

    my $site_type = $self->config->{site_type};
    if ( $site_type eq 'staff' ) {
        $self->_public_routes_staff;
    }
    elsif ( $site_type eq 'visit' ) {
        $self->_public_routes_visit;
    }
    elsif ( $site_type eq 'all' ) {
        $self->_public_routes_staff;
        $self->_public_routes_visit;
    }
    else {
        $self->log->warn("Not allowed site_type: $site_type");
    }

    $r->get('/browse-happy')->to('root#browse_happy');
}

=head2 _public_routes_staff

=cut

sub _public_routes_staff {
    my $self = shift;
    my $r    = $self->routes;

    $r->get('/login')->to('user#login_form');
    $r->post('/login')->to('user#login');
    $r->get('/logout')->to('user#signout');

    $r->get('/order/:order_id/return')->to('order#order_return');
    $r->post('/order/:order_id/return')->to('order#create_order_return');
    $r->get('/order/:order_id/return/success')->to('order#order_return_success');
    $r->get('/order/:order_id/extension')->to('order#order_extension');
    $r->post('/order/:order_id/extension')->to('order#create_order_extension');
    $r->get('/order/:order_id/extension/success')->to('order#order_extension_success');
    $r->get('/stat/events/seoul')->to('statistic#events_seoul');
}

=head2 _public_routes_visit

=cut

sub _public_routes_visit {
    my $self = shift;
    my $r    = $self->routes;

    $r->any('/visit')->to('booking#visit');

    $r->get('/coupon')->to('coupon#index');
    $r->post('/coupon/validate')->to('coupon#validate');

    $r->get('/events/seoul')->to('event#seoul');
}

=head2 _private_routes

=cut

sub _private_routes {
    my $self = shift;
    my $root = $self->routes;

    my $r   = $root->under('/')->to('user#auth');
    my $csv = $root->under('/csv')->to('user#auth');
    $csv->get('/user')->to('CSV#user');
    $csv->get('/clothes')->to('CSV#clothes');

    ## Add prerix `api_` to all API controller methods
    ## to prevent deep recusion with helpers
    my $api = $root->under('/api')->to('user#auth');
    $api->post('/user')->to('API#api_create_user');
    $api->get('/user/:id')->to('API#api_get_user');
    $api->put('/user/:id')->to('API#api_update_user');
    $api->delete('/user/:id')->to('API#api_delete_user');
    $api->get('/user/:id/search/clothes')->to('API#api_search_clothes_user');
    $api->get('/user-list')->to('API#api_user_list');

    $api->post('/order')->to('API#api_create_order');
    ## not `get_order` for prevent deep recursion with get_order helper
    $api->get('/order/:id')->to('API#api_get_order');
    $api->put('/order/:id')->to('API#api_update_order');
    $api->delete('/order/:id')->to('API#api_delete_order');
    $api->put('/order/:id/unpaid')->to('API#api_update_order_unpaid');
    $api->put('/order/:id/return-part')->to('API#api_order_return_part');
    $api->get('/order/:id/set-package')->to('API#api_order_set_package');
    $api->get('/order-list')->to('API#api_order_list');

    ## prevent deep recursion with create_order_detail helper
    $api->post('/order_detail')->to('API#api_create_order_detail');

    $api->post('/clothes')->to('API#api_create_clothes');
    $api->get('/clothes/:code')->to('API#api_get_clothes');
    $api->put('/clothes/:code')->to('API#api_update_clothes');
    $api->delete('/clothes/:code')->to('API#api_delete_clothes');
    $api->put('/clothes/:code/tag')->to('API#api_update_clothes_tag');
    $api->any( [ 'POST', 'PUT' ] => '/clothes/:code/discard' )
        ->to('API#api_update_clothes_discard');
    $api->get('/clothes-list')->to('API#api_clothes_list');
    $api->put('/clothes-list')->to('API#api_update_clothes_list');

    $api->post('/tag')->to('API#api_create_tag');
    $api->get('/tag/:id')->to('API#api_get_tag');
    $api->put('/tag/:id')->to('API#api_update_tag');
    $api->delete('/tag/:id')->to('API#api_delete_tag');

    $api->post('/donation')->to('API#api_create_donation');
    $api->put('/donation/:id')->to('API#api_update_donation');

    $api->post('/group')->to('API#api_create_group');

    $api->post('/suit')->to('API#api_create_suit');
    $api->delete('/suit/:code')->to('API#api_delete_suit');

    $api->post('/sms')->to('API#api_create_sms');
    $api->put('/sms/:id')->to('API#api_update_sms');
    $api->post('/sms/validation')->to('API#api_create_sms_validation');

    $api->get('/search/user')->to('API#api_search_user');
    $api->get('/search/user/late')->to('API#api_search_late_user');
    $api->get('/search/donation')->to('API#api_search_donation');
    $api->get('/search/sms')->to('API#api_search_sms');

    $api->get('/gui/staff-list')->to('API#api_gui_staff_list');
    $api->put('/gui/booking/:id')->to('API#api_gui_update_booking');
    $api->get('/gui/booking-list')->to('API#api_gui_booking_list');
    $api->get('/gui/timetable/:ymd')->to('API#api_gui_timetable');
    $api->get('/gui/user/:id/avg')->to('API#api_gui_user_id_avg');
    $api->get('/gui/user/:id/avg2')->to('API#api_gui_user_id_avg2');

    $api->any('/postcode/search')->to('API#api_postcode_search');

    $api->post('/photos')->to('API#api_upload_photo');

    $r->get('/')->to('root#index');

    $r->get('/tag')->to('tag#index');

    $r->get('/user')->to('user#index');
    $r->get('/user/:id')->to('user#user');
    ## for prevent deep recusion with helper 'search_clothes'
    $r->get('/user/:id/search/clothes')->to('user#user_search_clothes');

    $r->get('/new-clothes')->to('clothes#add');
    $r->get('/clothes')->to('clothes#index');
    $r->get('/clothes/:code')->to('clothes#clothes');
    $r->get('/clothes/:code/pdf')->to('clothes#clothes_pdf');

    $r->get('/rental')->to('rental#index');
    $r->get('/rental/:ymd')->to('rental#ymd');

    $r->get('/order')->to('order#index');
    $r->post('/order')->to('order#create');
    $r->get('/order/:id')->to('order#order');
    $r->post('/order/:id/update')->to('order#update');

    $r->get('/booking')->to('booking#index');
    $r->get('/booking/:ymd')->to('booking#ymd');
    $r->get('/booking/:ymd/open')->to('booking#open');
    $r->any('/visit2')->to('booking#visit2');

    $r->get('/timetable')->to('timetable#index');
    $r->get('/timetable/:ymd')->to('timetable#ymd');

    $r->get('/sms')->to('SMS#index');

    $r->get('/donation')->to('donation#index');
    $r->get('/donation/:id')->to('donation#donation');

    $r->get('/stat/bestfit')->to('statistic#bestfit');
    $r->get('/stat/clothes/amount')->to('statistic#clothes_amount');
    $r->get('/stat/clothes/amount/category/:category/gender/:gender')
        ->to('statistic#clothes_amount_category_gender');
    $r->get('/stat/clothes/hit')->to('statistic#clothes_hit');
    $r->get('/stat/clothes/hit/:category')->to('statistic#clothes_hit_category');
    $r->get('/stat/clothes/rent')->to('statistic#clothes_rent');
    $r->get('/stat/clothes/rent/:category')->to('statistic#clothes_rent_category');
    $r->get('/stat/status')->to('statistic#status');
    $r->get('/stat/status/:ymd')->to('statistic#status_ymd');
    $r->get('/stat/visitor')->to('statistic#visitor');
    $r->get('/stat/visitor/:ymd')->to('statistic#visitor_ymd');

    $r->get('/volunteers')->to('volunteer#index');

    $r->any('/size/guess')->to('size#guess');
}

=head2 _2depth_private_routes

=cut

sub _2depth_private_routes {
    my $self = shift;
    my $r    = $self->routes->under('/')->to('user#auth');

    my $income = $r->under('/income')->to('income#auth');

    $income->get('/')->to('Income#today');
    $income->get('/logout')->to('Income#logout');
    $income->get('/:ymd')->to('Income#ymd')->name('income.ymd');
}

1;

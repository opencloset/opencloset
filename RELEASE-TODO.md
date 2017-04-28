    $ cd OpenCloset-Schema/
    $ mysql < db/alter/124-coupon-extra.sql
    $ mysql < db/alter/126-visitor-rate-stat.sql
    $ closetpan OpenCloset::Schema             # 0.052
    $ closetpan OpenCloset::Plugin::Helpers    # v0.0.18
    $ grunt

v1.9.4

    $ closetpan OpenCloset::Common             # v0.0.17
    $ closetpan OpenCloset::Plugin::Helpers    # v0.0.17

v1.9.3

    $ grunt

v1.9.1

    $ cd OpenCloset-Schema/
    $ mysql < db/alter/122-visitor-online.sql
    $ closetpan OpenCloset::Schema    # 0.050
    $ grunt

v1.9.0

    $ grunt

v1.8.56

    $ grunt

v1.8.53

    $ closetpan OpenCloset::Common    # v0.0.15
    $ grunt

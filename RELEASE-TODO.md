    $ closetpan -n OpenCloset::API    # v0.1.15

    $ closetpan OpenCloset::Common    # v0.1.10
    $ grunt

    $ closetpan -n OpenCloset::API    # v0.1.7
    $ cd /path/to/OpenCloset-Schema/
    $ mysql < db/alter/142-event-type.sql
    $ mysql < db/alter/143-order-tag.sql

    # 아래는 이슈에서 별도록 설명함
    # https://github.com/opencloset/opencloset/issues/1517#issuecomment-447557950
    # add events
    # execute sql queries

    $ closetpan OpenCloset::Schema             # 0.060
    $ closetpan OpenCloset::Plugin::Helpers    # v0.0.28

    # app.conf 의 %BOOKING_SLOT 을 app.conf.sample 과 동일하게 설정

    $ grunt # 1539, 1562, 1718
    $ ubic reload opencloset.visit

v1.12.11

    $ closetpan OpenCloset::Cron::Event            # v0.1.2
    $ closetpan OpenCloset::Events::EmploymentWing # v0.1.0
    $ closetpan OpenCloset::Common                 # v0.1.8
    $ grunt
    # monitor 의 새로운 버전이 배포된 후에 배포

v1.12.10

    $ grunt
    $ closetpan OpenCloset::Common # v0.1.7
    $ closetpan OpenCloset::API    # v0.1.5

v1.12.9

    $ mysql < db/alter/136-coupon-limit.sql
    $ closetpan OpenCloset::API    # v0.1.2
    $ closetpan OpenCloset::Schema # 0.056

v1.12.8

v1.12.7

v1.12.6

v1.12.5

v1.12.4

    $ grunt

v1.12.3

    $ grunt
    $ mysql < db/alter/134-booking-desc.sql # already finished
    $ closetpan OpenCloset::Schema # 0.055  # already finished

v1.12.2

    $ grunt

v1.12.1

    $ grunt
    $ closetpan OpenCloset::Size::Guess::DB    # 0.008

v1.12.0

    # add below to app.conf
    redis_url => $ENV{OPENCLOSET_REDIS_URL} || 'redis://localhost:6379',

    # remove 'new-clothes' config at app.conf

    $ closetpan OpenCloset::API    # v0.1.1

v1.11.0

    $ closetpan OpenCloset::API    # v0.1.0

v1.10.16

    $ grunt

v1.10.15

v1.10.14

    $ grunt
    $ cpanm WebService::Jandi::WebHook
    # app.conf
    jandi => { hook => $ENV{OPENCLOSET_JANDI_WEBHOOK_URL} }

v1.10.13

    $ closetpan OpenCloset::API             # v0.0.5
    $ closetpan OpenCloset::Plugin::Helpers # v0.0.23

v1.10.12

v1.10.11

v1.10.10

    $ grunt

v1.10.9

    $ grunt

v1.10.8

v1.10.7

    $ mysql < db/alter/131-agent.sql
    $ closetpan OpenCloset::Schema    # 0.054
    $ closetpan OpenCloset::API       # v0.0.4
    $ grunt

v1.10.6

    $ grunt

v1.10.5

    $ grunt

v1.10.4

    $ grunt
    $ closetpan OpenCloset::Events::EmploymentWing    # v0.0.3
    # Configure `dressfree` at app.conf

v1.10.3

    $ grunt
    $ closetpan OpenCloset::Cron::Visitor
    $ ubic restart opencloset.cron.visitor

v1.10.2

v1.10.1

    $ closetpan OpenCloset::API    # v0.0.3
    $ grunt

v1.10.0

    $ closetpan OpenCloset::API
    $ closetpan OpenCloset::Calculator::LateFee     # v0.3.0
    $ closetpan OpenCloset::DB::Plugin::Order::Sale # v0.002
    $ closetpan OpenCloset::Plugin::Helpers         # v0.0.22
    $ bower install
    $ grunt

v1.9.18

    $ closetpan OpenCloset::Calculator::LateFee    # v0.2.3

v1.9.17

v1.9.16

    $ closetpan OpenCloset::Calculator::LateFee    # v0.2.2
    $ grunt

v1.9.15

v1.9.14

v1.9.13

v1.9.12

    $ grunt
    $ closetpan OpenCloset::Events::EmploymentWing

v1.9.11

v1.9.10

    $ bower install
    $ grunt

v1.9.7

    $ closetpan OpenCloset::Common    # v0.1.0

v1.9.5

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

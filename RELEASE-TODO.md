배포 전 해야할 일들

    $ grunt

배포 후 해야할 일들

    $ ubic stop opencloset.cron.sms
    $ ubic stop opencloset.staff
    $ ubic stop opencloset.visit
    $ ubic stop opencloset.volunteer
    $ ubic stop opencloset.sms
    # 
    # staff, visit, volunteer 설정 수정 
    # 
    $ ubic start opencloset.sms
    $ ubic start opencloset.volunteer
    $ ubic start opencloset.visit
    $ ubic start opencloset.staff
    $ ubic start opencloset.cron.sms

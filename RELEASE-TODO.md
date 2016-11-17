배포 전 해야할 일들

    $ grunt
    $ mysql -u xxxx -p xxxx < /path/to/OpenCloset-Schema/db/alter/100-sms-macro.sql
    $ closetpan OpenCloset::Schema

`app.conf` 수정

```
113 line
+            'sms-macros'          => { text => 'SMS 매크로',             icon => 'envelope',  desc => '문자메세지 매크로를 관리합니다.', link => '/sms/macros',      },
```

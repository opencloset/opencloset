opencloset
==========

### SETUP

    $ export OPENCLOSET_DB=opencloset
    $ export OPENCLOSET_USERNAME=username    # DB username
    $ export OPENCLOSET_PASSWORD=password    # DB password
    $ mysql -u $OPENCLOSET_USERNAME -p -e 'CREATE DATABASE opencloset'
    $ mysql -u $OPENCLOSET_USERNAME -p $OPENCLOSET_DB < db/init.sql

### RUN

    ## set env
    $ export OPENCLOSET_DB=opencloset
    $ export OPENCLOSET_USERNAME=username
    $ export OPENCLOSET_PASSWORD=password

    ## run!
    $ plackup                         # or
    $ DBIC_TRACE=1 plackup -R bin/    # for development

### 이슈, 제안이나 의견

팀과 커뮤니케이션이 필요할때에는, email 이나 전화를 주셔도 됩니다만,
모두가 같이 공유되려면
[issues](https://github.com/opencloset/opencloset/issues) 또는 IRC
irc://irc.silex.kr/#opencloset 를 이용해주시면 됩니다.

지난 대화는 [IRC log](http://log.silex.kr/opencloset) 를 이용하세요.

- 메일링 <opencloset-program@googlegroups.com>
- 김도형 <keedi.k@gmail.com>
- 유용빈 <supermania@gmail.com>
- 조성재 <cho.sungjae@gmail.com>
- 홍형석 <aanoaa@gmail.com>

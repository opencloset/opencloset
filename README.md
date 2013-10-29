opencloset
==========

### 데이터베이스 초기화

MySQL을 사용해서 데이터베이스를 `opencloset`, 사용자 이름 `opencloset`,
비밀번호 `opencloset`으로 설정하려면 다음 명령을 이용합니다.

    $ mysql -u root -p -e 'GRANT ALL PRIVILEGES ON `opencloset`.* TO opencloset@localhost IDENTIFIED by "opencloset";'
    $ mysql -u opencloset -p -e 'CREATE DATABASE `opencloset` DEFAULT CHARACTER SET utf8;'
    $ mysql -u opencloset -p opencloset < db/init.sql


### 환경 변수 설정

MySQL 데이터베이스에 접속하며 `opencloset` 데이터베이스에
아이디 `opencloset`, 비밀번호 `opencloset`으로 접속하는 것이 기본 설정입니다.
설정을 변경하려면 다음 환경 변수를 조정합니다.
다음 예시는 기본 값으로 설정되어 있는 값입니다.

    $ export OPENCLOSET_DATABASE_DSN="dbi:mysql:opencloset:127.0.0.1"
    $ export OPENCLOSET_DATABASE_USER=opencloset
    $ export OPENCLOSET_DATABASE_PASS=opencloset
    $ export OPENCLOSET_DATABASE_OPTS='{ "mysql_enable_utf8": 1, "on_connect_do": "SET NAMES utf8", "quote_char": "`" }'

    # 설정파일 위치와 Project Root에 대한 환경변수를 설정합니다
    $ export MOJO_CONFIG=app.conf
    $ export MOJO_HOME=.

### RUN

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

opencloset
==========

## Requirements ##

node.js 를 사용할 수 있는 환경이라고 가정합니다.
[https://github.com/creationix/nvm](nvm) 의 사용을 추천합니다.

ruby를 사용할 수 있는 환경이라고 가정합니다.
rbenv 또는 rvm 의 사용을 추천합니다.

`scss` 파일의 컴파일을 위한 도구를 설치해야 합니다.

    $ gem install bundler
    $ bundle install

coffeescript 파일을 컴파일하고, 컴파일된 javascript 파일을 minify
하기위한 도구를 설치합니다.

    $ npm install -g grunt-cli
    $ npm install

### 데이터베이스 초기화

MySQL을 사용해서 데이터베이스를 `opencloset`, 사용자 이름 `opencloset`,
비밀번호 `opencloset`으로 설정하려면 다음 명령을 이용합니다.

    $ mysql -u root -p -e 'GRANT ALL PRIVILEGES ON `opencloset`.* TO opencloset@localhost IDENTIFIED by "opencloset";'
    $ mysql -u opencloset -p -e 'CREATE DATABASE `opencloset` DEFAULT CHARACTER SET utf8;'
    $ mysql -u opencloset -p opencloset < db/init.sql


### 설정 파일 생성

저장소에 `app.conf.sample` 파일이 있습니다.
이 파일을 `app.conf`로 복사한 후 자신의 설정에 맞도록 값을 변경합니다.

    $ cp app.conf.sample app.conf
    $ ... edit app.conf ...

현재 개발 중이고 `app.conf.sample` 파일을 수정해서 반영하고 있다면 심볼릭 링크를 걸도록 합니다.

    $ ln -sf app.conf.sample app.conf


### 환경 변수 설정

MySQL 데이터베이스에 접속하며 `opencloset` 데이터베이스에
아이디 `opencloset`, 비밀번호 `opencloset`으로 접속하는 것이 기본 설정입니다.
설정을 변경하려면 다음 환경 변수를 조정합니다.
다음 예시는 기본 값으로 설정되어 있는 값입니다.

    $ export OPENCLOSET_DATABASE_DSN="dbi:mysql:opencloset:127.0.0.1"
    $ export OPENCLOSET_DATABASE_USER=opencloset
    $ export OPENCLOSET_DATABASE_PASS=opencloset
    $ export OPENCLOSET_DATABASE_OPTS='{ "mysql_enable_utf8": 1, "on_connect_do": "SET NAMES utf8", "quote_char": "`" }'
    $ export OPENCLOSET_COOLSMS_USER=coolsms_username
    $ export OPENCLOSET_COOLSMS_PASS=coolsms_s3cr3t

    # 설정파일 위치와 Project Root에 대한 환경변수를 설정합니다
    $ export MOJO_CONFIG=app.conf
    $ export MOJO_HOME=.


### RUN

    $ plackup                         # or
    $ DBIC_TRACE=1 plackup -R bin/    # for development

`morbo`를 이용해서 실행할 명령을 한번에 입력하려면 다음처럼 명령을 실행합니다.

    $ PERL5LIB=lib:$PERL5LIB MOJO_HOME=. MOJO_CONFIG=app.conf morbo -w app.conf -w lib app.psgi

## front-end 파일의 수정 ##

scss 파일이나 coffeescript 파일이 추가 되었거나 변경되었다면, `grunt`
명령어를 이용해서 각각의 파일을 js, css 파일로 컴파일합니다.

    $ grunt

개발중에 있다면 `watch` 명령어를 통해 변경된 파일이 감지되면 자동으로
컴파일 되도록 할 수 있습니다.

    $ grunt watch

### 자바스크립트 수정

열린옷장 프로젝트의 자바스크립트는 커피스크립트를 이용해서 작성합니다.
자바스크립트를 수정해야 하면 커피스크립트 파일을 수정해주세요.

`grunt` 명령어를 이용해서 coffeescript 파일을 javascript 파일로
컴파일합니다.

    $ grunt coffee uglify

### 스타일시트 수정

열린옷장 프로젝트의 스타일시트는 SASS를 이용해서 작성합니다.
스타일시트를 수정해야 하면 `public/sass/*.sass` 파일을 수정해주세요.

`grunt` 명령어를 이용해서 scss 파일을 css 파일로 컴파일합니다.

    $ grunt compass

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

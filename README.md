opencloset
==========

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

### bundler

**TODO** 좀 더 친절한 문서화

    $ gem install bundler
    $ bundle install

### Grunt

**TODO** 좀 더 친절한 문서화

    $ npm install -g grunt-cli
    $ npm install
    $ grunt          # compile javascripts and scss
    $ grunt watch    # for development

### 자바스크립트 수정

열린옷장 프로젝트의 자바스크립트는 커피스크립트를 이용해서 작성합니다.
자바스크립트를 수정해야 하면 커피스크립트 파일을 수정해주세요.
커피스크립트를 사용하기 위해서는 `npm` 유틸리티가 필요합니다.
데비안 리눅스의 경우 다음 명령을 실행해 `npm` 유틸리티를 설치합니다.

    $ sudo apt-get install npm

`npm`을 설치한 후에는 커피스크립트 모듈을 설치해야 합니다.
전역으로 설치한다면 다음 명령을 실행합니다.

    $ sudo npm install -g coffee-script    # 또는 -g(global) 옵션을 줘서 전역으로 설치

별도의 터미널에서 다음 명령을 실행시켜 수정하는 커피스크립트가
자바스크립트로 바로바로 변환되도록 한 후 개발을 진행합니다.

    $ coffee --compile --watch public/js/

루트 권한이 없거나 사용자 디렉터리에서 커피스크립트를 관리하고 싶다면
프로젝트 루트 디렉터리에서 다음 명령을 실행합니다.

    $ npm install coffee-script

아무런 설정없이 앞의 명령을 실행하면 `node_modules` 디렉터리가 생기고
그 하부에 커피스크립트 관련 파일이 설치되므로 실행 방법은 다음과 같습니다.

    $ node_modules/.bin/coffee --compile --watch public/js/


### 스타일시트 수정

열린옷장 프로젝트의 스타일시트는 SASS를 이용해서 작성합니다.
스타일시트를 수정해야 하면 `public/sass/*.sass` 파일을 수정해주세요.
SASS 파일을 수정한 후 CSS로 빌드하기 위해서는 `sass`나 `compass`
유틸리티가 필요합니다. 다음 명령을 실행해서 `sass`나 `compass`를 설치합니다.

    $ gem install sass
    $ gem install compass

`sass`를 이용하는 경우 프로젝트 루트 디렉터리에서 다음 명령을 실행합니다.

    $ sass --style=compact --watch public/sass:public/css

`compass`를 이용하는 경우 `public` 디렉터리 하부로 들어간 후 다음 명령을 실행합니다.

    $ cd public
    $ compass watch


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

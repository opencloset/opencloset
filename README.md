opencloset
==========

## Version ##

v1.10.6

## Requirements ##

열린옷장 웹 시스템은 perl로 구현되어있으며, 부수적으로 node.js와 ruby 환경에서
제공하는 도구들을 활용하고 있습니다. 개발환경을 구성하기 위해서는 각각의 환경을
아래와 같이 구성해야합니다.

### perl ###

[perlbrew](http://perlbrew.pl/)와
[cpanm](http://search.cpan.org/~miyagawa/App-cpanminus-1.7039/bin/cpanm) 사용을
추천합니다. 아래 명령을 통해 CPAN(Comprehensive Perl Archive Network)에서 필요한
모듈을 설치하면 됩니다.

    $ cpanm --installdeps .
    $ cpanm --mirror https://cpan.theopencloset.net OpenCloset::Schema OpenCloset::Config OpenCloset::Size::Guess::DB OpenCloset::Size::Guess::BodyKit OpenCloset::Size::Guess::OpenCPU::RandomForest

### node.js ###

[nvm](https://github.com/creationix/nvm) 의 사용을 추천합니다.

coffeescript 파일을 컴파일하고, 컴파일된 javascript 파일을 minify
하기위해 [grunt](http://gruntjs.com/) 도구를 설치합니다.

    $ npm install -g grunt-cli
    $ npm install

front-end 패키지 관리를 위해 [bower](http://bower.io/)를 설치합니다.

    $ npm install -g bower

bower를 통해 front-end 패키지를 설치합니다.

    $ bower install

### 데이터베이스 초기화

MySQL을 사용해서 데이터베이스를 `opencloset`, 사용자 이름 `opencloset`,
비밀번호 `opencloset`으로 설정하려면 다음 명령을 이용합니다.

    $ mysql -u root -p -e 'GRANT ALL PRIVILEGES ON `opencloset`.* TO opencloset@localhost IDENTIFIED by "xxxxxxx";'
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
    $ export OPENCLOSET_COOLSMS_API_KEY=123456789ABCDEFG
    $ export OPENCLOSET_COOLSMS_API_SECRET=123456789ABCDEFG123456789ABCDEFG

    # 설정파일 위치와 Project Root에 대한 환경변수를 설정합니다
    $ export MOJO_CONFIG=app.conf
    $ export MOJO_HOME=.

### 우편번호검색 DB 파일 설치 ###

**dump 파일의 링크가 더이상 유효하지 않습니다.**

상황에 맞게 설정파일에서 `postcodify` 의 값을 수정합니다.
기본값은 SQLite 를 사용합니다.

#### MySQL ####

    $ wget http://storage.poesis.kr/downloads/post/postcodify.20141201.v2.mysqldump.xz
    $ xz -d postcodify.20141201.v2.mysqldump.xz
    $ mysql -u root -p -e 'GRANT ALL PRIVILEGES ON `postcodify`.* TO postcodify@localhost IDENTIFIED by "s3cr3t";'    # WARN: type your own secret password
    $ mysql -u postcodify -p -e 'CREATE DATABASE `postcodify` DEFAULT CHARACTER SET utf8;'
    $ mysql -u postcodify -p postcodify < postcodify.20141201.v2.mysqldump

#### SQLite ####

    $ wget -qO- https://raw.githubusercontent.com/aanoaa/p5-postcodify/develop/installer.sh | sh

`wget` 이 없으면, `curl` 로..

    $ curl
    https://raw.githubusercontent.com/aanoaa/p5-postcodify/develop/installer.sh
    | sh

### Redis ###

    $ sudo apt-get install redis-server

## RUN

    $ plackup                         # or
    $ DBIC_TRACE=1 plackup -R bin/    # for development

`morbo`를 이용해서 실행할 명령을 한번에 입력하려면 다음처럼 명령을 실행합니다.

    $ PERL5LIB=lib:$PERL5LIB MOJO_HOME=. MOJO_CONFIG=app.conf morbo -w app.conf -w lib app.psgi

## front-end 파일의 수정 ##

less 파일이나 coffeescript 파일이 추가 되었거나 변경되었다면, `grunt`
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

    $ grunt dist-js

### 스타일시트 수정

열린옷장 프로젝트의 스타일시트는 LESS를 이용해서 작성합니다.
스타일시트를 수정해야 하면 `less/*.less` 파일을 수정해주세요.

`grunt` 명령어를 이용해서 less 파일을 css 파일로 컴파일합니다.

    $ grunt dist-css

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

### LICENSING

This program is free software; you can redistribute it and/or modify
it under the terms of either:

1. the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

2. the "Artistic License" which comes with this Kit.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
the GNU General Public License or the Artistic License for more details.

You should have received a copy of the Artistic License with this
Kit, in the file named "Artistic".  If not, I'll be glad to provide one.

You should also have received a copy of the GNU General Public License
along with this program in the file named "Copying". If not, write to the
Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
Boston, MA 02110-1301, USA or visit their web page on the internet at
http://www.gnu.org/copyleft/gpl.html.

For those of you that choose to use the GNU General Public License,
my interpretation of the GNU General Public License is that no Perl
script falls under the terms of the GPL unless you explicitly put
said script under the terms of the GPL yourself.  Furthermore, any
object code linked with perl does not automatically fall under the
terms of the GPL, provided such object code only adds definitions
of subroutines and variables, and does not otherwise impair the
resulting interpreter from executing any standard Perl script.  I
consider linking in C subroutines in this manner to be the moral
equivalent of defining subroutines in the Perl language itself.  You
may sell such an object file as proprietary provided that you provide
or offer to provide the Perl source, as specified by the GNU General
Public License.  (This is merely an alternate way of specifying input
to the program.)  You may also sell a binary produced by the dumping of
a running Perl script that belongs to you, provided that you provide or
offer to provide the Perl source as specified by the GPL.  (The
fact that a Perl interpreter and your code are in the same binary file
is, in this case, a form of mere aggregation.)  This is my interpretation
of the GPL.  If you still have concerns or difficulties understanding
my intent, feel free to contact me.  Of course, the Artistic License
spells all this out for your protection, so you may prefer to use that.


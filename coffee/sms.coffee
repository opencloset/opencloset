$ ->
  macros =
    macro1:
      text: '직접 입력'
      msg:  ''
    macro2:
      text: '계좌 이체'
      msg:  '열린옷장에 결제할 금액은 X만Y천원 입니다. 국민은행 205737-04-003013'
    macro3:
      text: '전화 요망'
      msg:  '안녕하세요. 열린옷장입니다. 전화부탁드립니다.'
    macro4:
      text: '내용 증명'
      msg: '''00님 열린옷장 대여기간이 00일 연체되었습니다. 00일 0요일까지 반납이 되지 않을 시, 반납의사가 없다고 판단되어 채무불이행과 횡령죄가 성립됩니다.

따라서 내용증명서를 발송한 후, 서울 광진경찰서와 법적 절차를 통한 손해배상청구를 진행할 예정입니다. 꼭 반납 부탁 드립니다. 감사합니다.'''
    macro5:
      text: '온라인 배송 후 안내'
      msg:  '''[열린옷장] OOO님 온라인 의류 대여 서비스를 이용해주셔서 감사합니다!

* 의류배송 정보: CJ대한통운/ (운송장 번호 기재)

* 반납안내

1. 택배 반납시 반납일 1일전 발송(택배비는 본인부담): oo일에 받은 상자에 담아서 보내주세요(반납 예정일: oo일)
 - 주소: 서울시 광진구 아차산로 213 (화양동, 웅진빌딩) 403호 (우.05019)
 - 전화: 070-4325-7521

2. 방문 반납시: 웅진빌딩 4층 403호
 - 반납가능시간: 월~토 am 10:00 ~ pm 6:00 ( 운영시간 후 or 휴일 반납: 4층 엘리베이터 앞 노란 무인반납함에 넣어주세요. 단, 밤10시 이후에는 빌딩 보안상 출입이 통제 됩니다.)

3. 대여기간 연장 / 연체
 - 1일 연장시 전체 대여비의 20%에 해당하는 금액이 청구됩니다.
(대여기간 연장이 필요하신 경우에는 대여시 받으신 문자메시지를 확인하여 기간연장에 필요한 정보를 입력해서 보내주세요)
 - 연장 신청 하지 않고 연체가 발생될 경우: 1일당 전체 대여비의 30%에 해당하는 금액이 청구됩니다.

4. 대여기간 의류 손상 및 분실 배상규정
 - 의류 손상 혹은 분실의 경우에는 금액의 10배에 해당하는 금액이 청구됩니다.

열린옷장 서비스 이용에 문의사항이 있으시면, 유선/카카오톡 엘로아이디/홈페이지 통하여 문의 부탁드립니다!
감사합니다 :)'''
    macro6:
      text: '온라인 입금 안내'
      msg:  '[열린옷장] 대여 금액 00000원, 1시까지 입금해주세요. 국민은행 205737-04-003013'
    macro7:
      text: '온라인 자동 취소 고지'
      msg:  '[열린옷장] 00님 금일 3시까지 입금되지 않을 경우 발송 취소 됨을 알립니다.'
    macro8:
      text: 'SMS 인증발송'
      msg:  '열린옷장입니다. 전화번호 확인을 위해 SMS 확인 문자를 발송하였습니다. 인증번호는 OOOO입니다. 발송된 인증번호를 담당자에게 보여주시기 바랍니다'
    macro9:
      text: '최종통보'
      msg:  '[열린옷장] ooo님 대여기간이 oo일 연체되었습니다. 더 이상 반납의사가 없다고 판단되어 명일(0/0) 내용증명서가 발송됩니다. 추후 광진경찰서에 고소장 접수 후 법적 절차를 통해 정장을 회수할 예정입니다. 참고 바라며, 최종 고지하는 것이오니 바로 답변바랍니다.'
    macro10:
      text: '방문대여 예약 가이드'
      msg:  '[열린옷장] 방문대여 예약 가이드, 링크 참고하셔서 예약하세요.^^ http://goo.gl/3Q1BB9'
    macro11:
      text: '열린사진관 이용안내'
      msg: '''[열린사진관]
안녕하세요. OOO님! 열린옷장입니다.
내일(O월O일) 열린사진관 이용 안내 드립니다.

예약하신 시간은 오후 OO시이며,
신청하신 서비스는 정장대여, 사진촬영, 헤어, 메이크업입니다.

- 사진촬영만 하시는 경우
바라봄사진관으로 예약 시간에 맞춰 방문해 주세요.

- 헤어, 메이크업 후 사진촬영 하시는 경우
김청경오테르 홍대점으로 예약 시간에 맞춰 방문하셔서
헤어, 메이크업을 받으신 후 바라봄사진관으로 방문해 주세요.

사진촬영 비용은 5천원입니다. 비영리단체 바라봄사진관에
기부 형식으로 전달되므로 5천원은 현금으로 준비해주세요.


* 홍대 바라봄사진관 위치
http://goo.gl/pfeaU4

* 김청경오테르 홍대점 위치
http://goo.gl/l1hGQo

* 합정역 3번 출구에서 도보 5분 거리
* 김청경오테르에서 바라봄사진관까지는 도보 3분 거리입니다.'''
  
  updateMsgScreenWidth = ->
    msg   = $('textarea[name=msg]').prop('value')
    width = OpenCloset.strScreenWidth(msg)
    $('.msg-screen-width').html(width)

  $('textarea[name=msg]')
    .on( 'keyup', (e)  -> updateMsgScreenWidth() )
    .on( 'change', (e) -> updateMsgScreenWidth() )

  #
  # 전화번호로 숫자나 또는 주문서 번호(#숫자)만 입력 가능하게 함
  #
  $('input[name="to"]').mask '#00000000000',
    translation:
      '#':
        pattern:  /[#]/
        optional: true

  #
  # dynamic chosen item manupulation
  # http://stackoverflow.com/questions/11352207/jquery-chosen-plugin-add-options-dynamically
  #
  $('select[name=macro]').append("<option value=\"#{k}\">#{v.text}</option>") for k, v of macros
  $('select[name=macro]').trigger("liszt:updated")
  $('select[name=macro]').change ->
    $('textarea[name=msg]').prop( 'value', macros[ $(this).prop('value') ].msg )
    updateMsgScreenWidth()

  $('#btn-sms-send').click (e) ->
    to  = $('input[name=to]').prop('value')
    msg = $('textarea[name=msg]').prop('value')

    #
    # 휴대전화 점검
    #
    unless to
      OpenCloset.alert 'danger', '휴대전화를 입력해주세요.'
      $('input[name=to]').focus()
      return
    unless /^#?\d+$/.test( to )
      OpenCloset.alert 'danger', '유효하지 않은 휴대전화입니다.'
      $('input[name=to]').focus()
      return
    if /^999/.test( to )
      OpenCloset.alert 'danger', '전송 불가능한 휴대전화입니다.'
      $('input[name=to]').focus()
      return

    #
    # 메시지 점검
    #
    unless msg
      OpenCloset.alert 'danger', '전송할 메시지를 입력해주세요.'
      $('input[name=msg]').focus()
      return

    #
    # 전송
    #
    OpenCloset.sendSMS to, msg
    $('input[name=to]').prop('value', '')
    $('input[name=msg]').prop('value', '')
    OpenCloset.alert 'success', '문자 메시지를 전송했습니다.'

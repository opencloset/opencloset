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
      msg:  '[열린옷장] CJ대한통운/1234-5678-9000 반납 시, 받은 상자에 담아 보내주세요. ^^'
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

  updateMsgScreenWidth = ->
    msg   = $('textarea[name=msg]').prop('value')
    width = OpenCloset.strScreenWidth(msg)
    $('.msg-screen-width').html(width)

  $('textarea[name=msg]')
    .on( 'keyup', (e)  -> updateMsgScreenWidth() )
    .on( 'change', (e) -> updateMsgScreenWidth() )

  #
  # 전화번호에 `-` 기호를 무시하도록 함
  #
  $('input[type="tel"]').mask('00000000000')

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
    unless /^\d+$/.test( to )
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

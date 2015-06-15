$ ->
  macros =
    macro1:
      text: '직접 입력'
      msg:  ''
    macro2:
      text: '계좌 이체'
      msg:  '열린옷장에 결제할 금액은 X만Y천원 입니다. 국민은행 205701-04-269524'
    macro3:
      text: '전화 요망'
      msg:  '안녕하세요. 열린옷장입니다. 전화부탁드립니다.'
    macro4:
      text: '내용 증명'
      msg: '''xxx님 열린옷장 대여기간이 xx일 연체되었습니다. xx일 x요일까지 반납이 되지 않을 시, 반납의사가 없다고 판단되어 채무불이행과 횡령죄가 성립됩니다.

따라서 내용증명서를 발송한 후, 서울 광진경찰서와 법적 절차를 통한 손해배상청구를 진행할 예정입니다. 꼭 반납 부탁 드립니다. 감사합니다.'''

  updateMsgScreenWidth = ->
    msg   = $('textarea[name=msg]').prop('value')
    width = OpenCloset.strScreenWidth(msg)
    $('.msg-screen-width').html(width)

  $('textarea[name=msg]')
    .on( 'keyup', (e)  -> updateMsgScreenWidth() )
    .on( 'change', (e) -> updateMsgScreenWidth() )

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

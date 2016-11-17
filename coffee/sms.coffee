$ ->
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

  $('select[name=macro]').change ->
    msg  = $(@).val()
    from = $(@).find(':selected').data('from')
    $('textarea[name=msg]').val(msg)
    $('input[name=from]').val(from)
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

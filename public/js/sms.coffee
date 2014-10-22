$ ->
  $('#btn-sms-send').click (e) ->
    to  = $('#form-field-1').prop('value')
    msg = $('#form-field-2').prop('value')

    #
    # 휴대전화 점검
    #
    unless to
      OpenCloset.alert 'danger', '휴대전화를 입력해주세요.'
      $('#form-field-1').focus()
      return
    unless /^\d+$/.test( to )
      OpenCloset.alert 'danger', '유효하지 않은 휴대전화입니다.'
      $('#form-field-1').focus()
      return
    if /^999/.test( to )
      OpenCloset.alert 'danger', '전송 불가능한 휴대전화입니다.'
      $('#form-field-1').focus()
      return

    #
    # 메시지 점검
    #
    unless msg
      OpenCloset.alert 'danger', '전송할 메시지를 입력해주세요.'
      $('#form-field-2').focus()
      return

    $.ajax '/api/gui/utf8/gcs-columns.json',
      type: 'POST'
      data: { str: msg }
      success: (data, textStatus, jqXHR) ->
        gcs_columns = data.ret
        console.log gcs_columns
        if gcs_columns > 88
          console.log OpenCloset.alert 'danger', "메시지가 너무 깁니다. (#{gcs_columns} 바이트)"
          $('#form-field-2').focus()
          return

        #
        # 전송
        #
        console.log( to )
        console.log( msg )

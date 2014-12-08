$ ->
  Window::show_box = (id) ->
    $('.widget-box.visible').removeClass('visible')
    $("##{id}").addClass('visible')

  #
  # SMS 인증하기 버튼 클릭
  #
  $('#btn-forgot-sms-send').click (e) ->
    e.preventDefault()

    name  = $("input[name=forgot-name]").val()
    phone = $("input[name=forgot-phone]").val()

    #
    # 휴대전화 점검
    #
    unless phone
      OpenCloset.alert 'danger', '휴대전화를 입력해주세요.', '#forgot-alert'
      return
    unless /^\d+$/.test( phone )
      OpenCloset.alert 'danger', '유효하지 않은 휴대전화입니다.', '#forgot-alert'
      return
    if /^999/.test( phone )
      OpenCloset.alert 'danger', '전송 불가능한 휴대전화입니다.', '#forgot-alert'
      return

    #
    # 문자 전송
    #
    OpenCloset.sendSMSValidation(name, phone)

    #
    # 입력 양식 초기화
    #
    $("input[name=forgot-name]").val('')
    $("input[name=forgot-phone]").val('')

    #
    # 로그인 양식 표시
    #
    show_box('login-box')

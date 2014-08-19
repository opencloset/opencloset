$ ->
  #
  # 사용자 약관
  #
  $("#btn-service-disagree").click (e) ->
    $("input[name=service]").prop( "checked", false )
    $("#modal-service .modal-body").scrollTop(0)
    $("#modal-service").modal('hide')
  $("#btn-service-agree").click (e) ->
    $("input[name=service]").prop( "checked", true )
    $("#modal-service .modal-body").scrollTop(0)
    $("#modal-service").modal('hide')
  $("input[name=service]").click (e) ->
    if $(this).prop( "checked" )
      $(this).prop( "checked", false )
      $("#modal-service").modal('show')

  #
  # 개인정보 이용안내
  #
  $("#btn-privacy-disagree").click (e) ->
    $("input[name=privacy]").prop( "checked", false )
    $("#modal-privacy .modal-body").scrollTop(0)
    $("#modal-privacy").modal('hide')
  $("#btn-privacy-agree").click (e) ->
    $("input[name=privacy]").prop( "checked", true )
    $("#modal-privacy .modal-body").scrollTop(0)
    $("#modal-privacy").modal('hide')
  $("input[name=privacy]").click (e) ->
    if $(this).prop( "checked" )
      $(this).prop( "checked", false )
      $("#modal-privacy").modal('show')

  visitError = (msg) ->
    $('#visit-alert').prepend("<div class=\"alert alert-danger\"><button class=\"close\" type=\"button\" data-dismiss=\"alert\">&times;</button>#{msg}</div>")
    setTimeout ->
      $('.alert').remove()
    , 3000

  beforeSendSMS = () ->
    $(".sms").removeClass('block').hide()
    $("#btn-sms-confirm-label").html('SMS 인증번호 전송')
    $("#btn-sms-confirm").prop( "disabled", false )
  beforeSendSMS()

  #
  # 새로 쓰기 버튼 클릭
  #
  $('#btn-sms-reset').click (e) -> beforeSendSMS()

  #
  # SMS 인증하기 버튼 클릭
  #
  $('#btn-sms-confirm').click (e) ->
    e.preventDefault()

    name    = $("input[name=name]").val()
    phone   = $("input[name=phone]").val()
    service = $("input[name=service]").prop( "checked" )
    privacy = $("input[name=privacy]").prop( "checked" )
    sms     = $("input[name=sms]").val()

    if name && phone && service && privacy && sms
      $('#visit-form').submit()
    else
      #
      # 이름 점검
      #
      unless name
        visitError '이름을 입력해주세요.'
        return

      #
      # 휴대전화 점검
      #
      unless phone
        visitError '휴대전화를 입력해주세요.'
        return

      #
      # 서비스 이용약관 점검
      #
      unless service
        visitError '서비스 이용약관을 확인해주세요.'
        return

      #
      # 개인정보 이용안내 점검
      #
      unless privacy
        visitError '개인정보 이용안내를 확인해주세요.'
        return

      #
      # 인증번호 발송
      #   - sms 발송 HTTP 요청
      #   - 인증번호 입력창 보이게 하기
      #   - submit 버튼 레이블 변경
      #   - 남은 시간 표시
      #
      $(".sms").addClass('block').show()
      $("#btn-sms-confirm-label").html('SMS 인증하기')

      validate_end = moment().add('m', 3)
      $("#sms-remain-seconds").html( validate_end.diff( moment(), 'seconds' ) )
      timer = setInterval () ->
        validate_remain = validate_end.diff( moment(), 'seconds' )
        if validate_remain > 0
          $("#sms-remain-seconds").html(validate_remain)
        else
          $("#sms-remain-seconds").html(0)
          $("#btn-sms-confirm").prop( "disabled", true )
          clearInterval(timer)
      , 500

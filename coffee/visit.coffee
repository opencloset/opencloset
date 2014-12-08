$ ->
  $("input[name=booking]").val(undefined)
  $(".chosen-select").chosen()

  #
  # 대여 목적
  #
  $(".purpose .clickable.label").click ->
    old_purpose = $("input[name=purpose]").val()
    new_purpose = $(@).text()
    $("input[name=purpose]").prop( "value", $.trim( "#{old_purpose} #{new_purpose}" ) )

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
  # SMS 인증 콜백
  # - 인증번호 발송 HTTP 요청
  # - 인증번호 입력창 보이게 하기
  # - submit 버튼 레이블 변경
  # - 남은 시간 표시
  #
  validateSMS = (name, phone) ->
    success_cb = ( data, textStatus, jqXHR ) ->
      $(".sms").addClass('block').show()
      $("#btn-sms-confirm-label").html('SMS 인증하기')

      validate_end = moment().add('m', 5)
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

    error_cb = ( jqXHR, textStatus, errorThrown ) ->
      if jqXHR.status is 400
        switch jqXHR.responseJSON.error.str
          when 'name and phone does not match'
            OpenCloset.alert 'danger', '이름과 휴대전화 번호가 일치하지 않습니다.', '#visit-alert'
          else
            OpenCloset.alert 'danger', '인증 번호 전송에 실패했습니다.', '#visit-alert'
      else
        OpenCloset.alert 'danger', '인증 번호 전송에 실패했습니다.', '#visit-alert'

    OpenCloset.sendSMSValidation(name, phone, success_cb, error_cb)

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
        OpenCloset.alert 'danger', '이름을 입력해주세요.', '#visit-alert'
        return

      #
      # 휴대전화 점검
      #
      unless phone
        OpenCloset.alert 'danger', '휴대전화를 입력해주세요.', '#visit-alert'
        return
      unless /^\d+$/.test( phone )
        OpenCloset.alert 'danger', '유효하지 않은 휴대전화입니다.', '#visit-alert'
        return
      if /^999/.test( phone )
        OpenCloset.alert 'danger', '전송 불가능한 휴대전화입니다.', '#visit-alert'
        return

      #
      # 서비스 이용약관 점검
      #
      unless service
        OpenCloset.alert 'danger', '서비스 이용약관을 확인해주세요.', '#visit-alert'
        return

      #
      # 개인정보 이용안내 점검
      #
      unless privacy
        OpenCloset.alert 'danger', '개인정보 이용안내를 확인해주세요.', '#visit-alert'
        return

      validateSMS(name, phone)

  checkCancelBooking = () ->
    name          = $("input[name=name]").val()
    phone         = $("input[name=phone]").val()
    sms           = $("input[name=sms]").val()
    booking_saved = $("input[name=booking-saved]").val()

    #
    # 이름 점검
    #
    unless name
      OpenCloset.alert 'danger', '이름을 입력해주세요.', '#visit-alert'
      return

    #
    # 휴대전화 점검
    #
    unless phone
      OpenCloset.alert 'danger', '휴대전화를 입력해주세요.', '#visit-alert'
      return
    unless /^\d+$/.test( phone )
      OpenCloset.alert 'danger', '유효하지 않은 휴대전화입니다.', '#visit-alert'
      return
    if /^999/.test( phone )
      OpenCloset.alert 'danger', '전송 불가능한 휴대전화입니다.', '#visit-alert'
      return

    #
    # 인증번호 점검
    #
    unless sms
      OpenCloset.alert 'danger', '인증번호를 입력해주세요.', '#visit-alert'
      return

    #
    # 저장된 예약 아이디 점검
    #
    unless booking_saved
      OpenCloset.alert 'danger', '아직 예약한적이 없습니다.', '#visit-alert'
      return

    return true

  checkCreateOrUpdateBooking = () ->
    name    = $("input[name=name]").val()
    phone   = $("input[name=phone]").val()
    sms     = $("input[name=sms]").val()

    gender   = $("input[name=gender]:checked").val()
    email    = $("input[name=email]").val()
    address2 = $("input[name=address2]").val()
    birth    = $("input[name=birth]").val()
    height   = $("input[name=height]").val()
    weight   = $("input[name=weight]").val()
    booking  = $("input[name=booking]").val()
    purpose  = $("input[name=purpose]").val()
    purpose2 = $("input[name=purpose2]").val()

    #
    # 이름 점검
    #
    unless name
      OpenCloset.alert 'danger', '이름을 입력해주세요.', '#visit-alert'
      return

    #
    # 휴대전화 점검
    #
    unless phone
      OpenCloset.alert 'danger', '휴대전화를 입력해주세요.', '#visit-alert'
      return
    unless /^\d+$/.test( phone )
      OpenCloset.alert 'danger', '유효하지 않은 휴대전화입니다.', '#visit-alert'
      return
    if /^999/.test( phone )
      OpenCloset.alert 'danger', '전송 불가능한 휴대전화입니다.', '#visit-alert'
      return

    #
    # 인증번호 점검
    #
    unless sms
      OpenCloset.alert 'danger', '인증번호를 입력해주세요.', '#visit-alert'
      return

    #
    # 성별 점검
    #
    unless gender
      OpenCloset.alert 'danger', '성별을 입력해주세요.', '#visit-alert'
      return

    #
    # 전자우편 점검
    #
    unless email
      OpenCloset.alert 'danger', '전자우편을 입력해주세요.', '#visit-alert'
      return

    #
    # 주소 점검
    #
    unless address2
      OpenCloset.alert 'danger', '주소를 입력해주세요.', '#visit-alert'
      return

    #
    # 생년 점검
    #
    unless birth
      OpenCloset.alert 'danger', '생년을 입력해주세요.', '#visit-alert'
      return
    unless /^(19|20)|\d\d$/.test( birth )
      OpenCloset.alert 'danger', '유효하지 않은 생년입니다.', '#visit-alert'
      return

    #
    # 키 점검
    #
    unless height
      OpenCloset.alert 'danger', '키를 입력해주세요.', '#visit-alert'
      return
    unless /^\d+$/.test( height )
      OpenCloset.alert 'danger', '유효하지 않은 키입니다.', '#visit-alert'
      return

    #
    # 몸무게 점검
    #
    unless weight
      OpenCloset.alert 'danger', '몸무게를 입력해주세요.', '#visit-alert'
      return
    unless /^\d+$/.test( weight )
      OpenCloset.alert 'danger', '유효하지 않은 몸무게입니다.', '#visit-alert'
      return

    #
    # 방문 일자 점검
    #
    unless booking
      OpenCloset.alert 'danger', '방문 일자를 선택해주세요.', '#visit-alert'
      return

    #
    # 대여 목적 점검
    #
    unless purpose
      OpenCloset.alert 'danger', '대여 목적을 입력해주세요.', '#visit-alert'
      return

    return true

  cancelBooking = () ->
    return unless checkCancelBooking()
    $("input[name=booking]").prop( "value", '-1' )
    $('#visit-info-form').submit()

  createOrUpdateBooking = () ->
    return unless checkCreateOrUpdateBooking()
    $('#visit-info-form').submit()

  $("#btn-confirm-modal-cancel").click (e) ->
    type = $("#modal-confirm").data('type')
    $("#modal-confirm").modal('hide')
  $("#btn-confirm-modal-ok").click (e) ->
    $("#modal-confirm").modal('hide')
    type = $("#modal-confirm").data('type')
    if type is 'remove'
      cancelBooking()
    else if type is 'createorupdate'
      createOrUpdateBooking()

  confirmDialog = (type, msg) ->
    if type is 'remove'
      header = '예약을 취소하시겠습니까?'
    else if type is 'createorupdate'
      header = '예약을 확정하시겠습니까?'
    else
      return

    $('#confirmModalLabel').html(header)
    $('#modal-confirm .modal-body').html(msg)
    $("#modal-confirm").data('type', type)
    $("#modal-confirm").modal('show')

  #
  # 예약 취소 버튼 클릭
  #
  $('#btn-booking-cancel').click (e) ->
    e.preventDefault()
    return unless checkCancelBooking()

    booking_saved = $("input[name=booking-saved]").val()
    booking_ymd   = $("input[name=booking-saved]").data('ymd')
    booking_hm    = $("input[name=booking-saved]").data('hm')

    return unless booking_saved

    name = $("input[name=name]").val()
    msg  = "<p>#{name}님, <strong>#{booking_ymd} #{booking_hm}</strong>의 열린옷장 방문 예약을 취소하시겠습니까?</p>"

    confirmDialog 'remove', msg

  #
  # 예약 신청 버튼 클릭
  #
  $('#btn-info').click (e) ->
    e.preventDefault()
    return unless checkCreateOrUpdateBooking()

    booking = $("#lbl-booking").text()
    booking = booking.replace /^\s+|\s+$/g, ""
    booking = booking.replace /^-\s+/, ""
    return unless booking

    name = $("input[name=name]").val()
    msg  = "<p>#{name}님, <strong>#{booking}</strong>에 열린옷장으로 방문하시겠습니까?</p>"
    msg  += '<p>열린옷장 방문시 <strong>정시</strong>에 대여자 <strong>본인만</strong> 방문 부탁드립니다. :)</p>'

    confirmDialog 'createorupdate', msg

  #
  # 방문 일자 선택 버튼 클릭
  #
  $('#btn-booking').click (e) ->
    e.preventDefault()

    phone          = $("input[name=phone]").val()
    sms            = $("input[name=sms]").val()
    gender         = $("input[name=gender]:checked").val()
    old_booking_id = $("input[name=booking]").prop("value")

    $.ajax "/api/gui/booking-list.json",
      type: 'GET'
      data:
        phone:  phone
        sms:    sms
        gender: gender
      success: (data, textStatus, jqXHR) ->
        #
        # update booking
        #
        $("#booking-list").html('')
        for booking in data
          compiled = _.template( $('#tpl-booking').html() )
          $("#booking-list").append( $(compiled(booking)) )
          $("input[type='radio'][name='booking_id'][value='#{ old_booking_id }']").prop( "checked", true )
      error: (jqXHR, textStatus, errorThrown) ->
        if jqXHR.status is 404
          template = _.template( $('#tpl-booking-error-404').html() )
          $("#booking-list").append( $(template()) )

  #
  # 방문 일자 모달의 취소 버튼
  #
  $("#btn-booking-modal-cancel").click (e) ->
    $("#modal-booking .modal-body").scrollTop(0)
    $("#modal-booking").modal('hide')

  #
  # 방문 일자 모달의 확인 버튼
  #
  $("#btn-booking-modal-confirm").click (e) ->
    booking = $("input[type='radio'][name='booking_id']:checked")
    if booking
      $("input[name=booking]").prop( "value", booking.data('id') )
      $("#lbl-booking").html(" - #{booking.data('ymd')} #{booking.data('hm')}")
      $("#modal-booking .modal-body").scrollTop(0)
      $("#modal-booking").modal('hide')

  #
  # 성별 변경시 방문 일자를 다시 선택하게 함
  #
  $("input[name=gender]").click (e) ->
    $("input[name=booking]").prop( "value", '' )
    $("#lbl-booking").html('')

  #
  # 생년에 생년월일을 입력하지 못하게 함
  #
  $('input[name="birth"]').mask('0000')

  #
  # 전화번호에 `-` 기호를 무시하도록 함
  #
  $('input[type="tel"]').mask('00000000000')

  #
  # 주소검색
  #
  $("#postcodify").postcodify
    api: "/api/postcode/search"
    timeout: 10000    # 10 seconds
    insertDbid : ".postcodify_dbid"
    insertAddress : ".postcodify_address"
    insertJibeonAddress: ".postcodify_jibeonaddress"
    searchButtonContent: '주소검색'
    onReady: ->
      $("#postcodify").find('.postcodify_search_controls.postcode_search_controls')
        .addClass('input-group').find('input[type=text]')
        .addClass('form-control').val($('.postcodify_address').val()).end().find('button')
        .addClass('btn btn-default btn-sm')
        .wrap('<span class="input-group-btn"></span>')
    afterSelect: (selectedEntry) ->
      $("#postcodify").find('.postcodify_search_result.postcode_search_result')
        .remove()
    afterSearch: (keywords, results, lang, sort) ->
      $('summary.postcodify_search_status.postcode_search_status').hide()

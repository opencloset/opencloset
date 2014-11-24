$ ->
  signup = false
  $("input[name=booking]").val(undefined)

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

  setTimeout ->
    $('.alert').remove()
  , 5000
  visitError = (msg) ->
    $('#visit-alert').prepend("<div class=\"alert alert-danger\"><button class=\"close\" type=\"button\" data-dismiss=\"alert\">&times;</button>#{msg}</div>")
    setTimeout ->
      $('.alert').remove()
    , 5000

  beforeSendSMS = () ->
    $(".sms").removeClass('block').hide()
    $("#btn-sms-confirm-label").html('SMS 인증번호 전송')
    $("#btn-sms-confirm").prop( "disabled", false )
  beforeSendSMS()

  $(".signup").removeClass('block').hide()

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
  validateSMS = (phone) ->
    OpenCloset.sendSMSValidation(phone)

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

    gender  = $("input[name=gender]:checked").val()
    email   = $("input[name=email]").val()
    address = $("input[name=address]").val()
    birth   = $("input[name=birth]").val()

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
      unless /^\d+$/.test( phone )
        visitError '유효하지 않은 휴대전화입니다.'
        return
      if /^999/.test( phone )
        visitError '전송 불가능한 휴대전화입니다.'
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

      if signup
        #
        # 성별 점검
        #
        unless gender
          visitError '성별을 입력해주세요.'
          return

        #
        # 전자우편 점검
        #
        unless email
          visitError '전자우편을 입력해주세요.'
          return

        #
        # 주소 점검
        #
        unless address
          visitError '주소를 입력해주세요.'
          return

        #
        # 생년 점검
        #
        unless birth
          visitError '생년을 입력해주세요.'
          return
        unless /^(19|20)|\d\d$/.test( birth )
          visitError '유효하지 않은 생년입니다.'
          return

        #
        # - 사용자 추가
        # - 인증번호 발송
        #
        $.ajax "/api/user.json",
          type: 'POST'
          data:
            name:    name
            email:   email
            address: address
            gender:  gender
            phone:   phone
            birth:   birth
          success: (data, textStatus, jqXHR) ->
            signup = false
            validateSMS(phone)
          error: (jqXHR, textStatus, errorThrown) ->
            visitError '서버 오류가 발생했습니다.'
      else
        #
        # - 사용자 존재 확인
        # - 인증번호 발송
        #
        $.ajax "/api/search/user.json",
          type: 'GET'
          data: { q: phone }
          success: (data, textStatus, jqXHR) ->
            unless data.length == 1
              visitError '휴대전화가 중복되었습니다.'
              return

            user = data[0]
            unless user.name == name
              visitError '이름과 휴대전화가 일치하지 않습니다.'
              return

            validateSMS(phone)
          error: (jqXHR, textStatus, errorThrown) ->
            type = jqXHR.status is 404 ? 'warning' : 'danger'
            if jqXHR.status is 404
              visitError '사용자 등록이 필요합니다. 추가 정보를 입력해주세요.'
              $(".signup").addClass('block').show()
              signup = true
            else
              visitError '서버 오류가 발생했습니다.'

  checkCancelBooking = () ->
    name          = $("input[name=name]").val()
    phone         = $("input[name=phone]").val()
    sms           = $("input[name=sms]").val()
    booking_saved = $("input[name=booking-saved]").val()

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
    unless /^\d+$/.test( phone )
      visitError '유효하지 않은 휴대전화입니다.'
      return
    if /^999/.test( phone )
      visitError '전송 불가능한 휴대전화입니다.'
      return

    #
    # 인증번호 점검
    #
    unless sms
      visitError '인증번호를 입력해주세요.'
      return

    #
    # 저장된 예약 아이디 점검
    #
    unless booking_saved
      visitError '아직 예약한적이 없습니다.'
      return

    return true

  checkCreateOrUpdateBooking = () ->
    name    = $("input[name=name]").val()
    phone   = $("input[name=phone]").val()
    sms     = $("input[name=sms]").val()

    gender   = $("input[name=gender]:checked").val()
    email    = $("input[name=email]").val()
    address  = $("input[name=address]").val()
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
      visitError '이름을 입력해주세요.'
      return

    #
    # 휴대전화 점검
    #
    unless phone
      visitError '휴대전화를 입력해주세요.'
      return
    unless /^\d+$/.test( phone )
      visitError '유효하지 않은 휴대전화입니다.'
      return
    if /^999/.test( phone )
      visitError '전송 불가능한 휴대전화입니다.'
      return

    #
    # 인증번호 점검
    #
    unless sms
      visitError '인증번호를 입력해주세요.'
      return

    #
    # 성별 점검
    #
    unless gender
      visitError '성별을 입력해주세요.'
      return

    #
    # 전자우편 점검
    #
    unless email
      visitError '전자우편을 입력해주세요.'
      return

    #
    # 주소 점검
    #
    unless address
      visitError '주소를 입력해주세요.'
      return

    #
    # 생년 점검
    #
    unless birth
      visitError '생년을 입력해주세요.'
      return
    unless /^(19|20)|\d\d$/.test( birth )
      visitError '유효하지 않은 생년입니다.'
      return

    #
    # 키 점검
    #
    unless height
      visitError '키를 입력해주세요.'
      return
    unless /^\d+$/.test( height )
      visitError '유효하지 않은 키입니다.'
      return

    #
    # 몸무게 점검
    #
    unless weight
      visitError '몸무게를 입력해주세요.'
      return
    unless /^\d+$/.test( weight )
      visitError '유효하지 않은 몸무게입니다.'
      return

    #
    # 방문 일자 점검
    #
    unless booking
      visitError '방문 일자를 선택해주세요.'
      return

    #
    # 대여 목적 점검
    #
    unless purpose
      visitError '대여 목적을 입력해주세요.'
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

    gender         = $("input[name=gender]:checked").val()
    old_booking_id = $("input[name=booking]").prop("value")

    $.ajax "/api/gui/booking-list.json",
      type: 'GET'
      data:
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

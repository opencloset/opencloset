$ ->
  $("input[name=booking]").val(undefined)

  #
  # 페이지 로드시 첫/두 번째 선호 색상 설정
  #
  if $("input[name=pre_color]").val()
    pre_color = $("input[name=pre_color]").val().split(',')
    $("select[name=pre_color1]").val(pre_color[0]).trigger("chosen:updated")
    $("select[name=pre_color2]").val(pre_color[1]).trigger("chosen:updated")

  #
  # 페이지 로드시 대여할 옷의 종류 설정
  #
  if $("input[name=pre_category]").val()
    pre_category = $("input[name=pre_category]").val().split(',')
    $("select[name=pre_category_temp]").val(pre_category).trigger("chosen:updated")

  #
  # 대여할 옷의 종류 변경시 pre_category 양식 자동 설정
  #
  $("select[name=pre_category_temp]").chosen({ width: "100%" }).change ->
    category = $(this).val() || []
    $("input[name=pre_category]").val category.join(',')
    #
    # 예상대여비 계산
    #
    costMap = OpenCloset.category
    costMap.tie.price = 2000
    expectedCost = 0
    seen = []
    _.map category, (c) -> seen[c] = true
    if seen.jacket and seen.pants and seen.tie then expectedCost -= costMap.tie.price
    _.each category, (el) ->
      expectedCost += costMap[el]['price']
    refreshExpectedFee(expectedCost)

  #
  # 첫/두 번째 선호 색상 변경시 pre_color 양식 자동 설정
  #
  $("select[name=pre_color1],select[name=pre_color2]").chosen({ width: "100%" }).change ->
    $("input[name=pre_color]").val [ $("select[name=pre_color1]").val(), $("select[name=pre_color2]").val() ].join(',')

  #
  # 착용 날짜
  #
  $("input[name=wearon_date]").datepicker(
    todayHighlight: true
    autoclose:      true
  ).on 'changeDate', (e) ->
    refreshExpectedFee()

  #
  # 대여 목적
  #
  purpose = $("select[name=purpose]").data('purpose')
  $("select[name=purpose]").chosen({ width: "100%" }).val(purpose).trigger("chosen:updated")

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

      validate_end = moment().add('m', 10)
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

    gender      = $("input[name=gender]:checked").val()
    email       = $("input[name=email]").val()
    address2    = $("input[name=address2]").val()
    birth       = $("input[name=birth]").val()
    booking     = $("input[name=booking]").val()
    wearon_date = $("input[name=wearon_date]").val()
    purpose     = $("select[name=purpose]").val()

    pre_category_temp = $("select[name=pre_category_temp]").val()
    pre_color1        = $("select[name=pre_color1]").val()

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
    unless /^([a-zA-Z0-9_.+-])+\@(([a-zA-Z0-9-])+\.)+([a-zA-Z0-9]{2,4})+$/.test( email )
      OpenCloset.alert 'danger', '유효하지 않은 전자우편입니다.', '#visit-alert'
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
    # 방문 일자 점검
    #
    unless booking
      OpenCloset.alert 'danger', '방문 일자를 선택해주세요.', '#visit-alert'
      return

    #
    # 착용 날짜 점검
    #
    unless wearon_date
      OpenCloset.alert 'danger', '착용 날짜를 입력해주세요.', '#visit-alert'
      return

    #
    # 대여 목적 점검
    #
    unless purpose
      OpenCloset.alert 'danger', '대여 목적을 입력해주세요.', '#visit-alert'
      return

    #
    # 대여할 옷의 종류 점검
    #
    unless pre_category_temp
      OpenCloset.alert 'danger', '대여할 옷의 종류를 입력해주세요.', '#visit-alert'
      return

    #
    # 첫 번째 선호하는 색상 점검
    #
    unless pre_color1
      OpenCloset.alert 'danger', '첫 번째 선호하는 색상을 입력해주세요.', '#visit-alert'
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
    msg  += '<p>'
    msg  += ' 방문 예약이 정상적으로 완료된 경우 방문시간 안내가 포함된 문자가 발송됩니다.'
    msg  += ' 문자가 발송되지 않은 경우 예약이 완료된 것이 아니니 다시 한번 예약을 진행해주시고,'
    msg  += ' 방문 예약 완료가 정상적으로 되지 않는 경우 열린옷장(070-4325-7521)'
    msg  += ' 혹은 카카오톡(goto.kakao.com/@열린옷장)으로 문의해주세요.'
    msg  += '</p>'

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

    unless /^(male|female)$/.test( gender )
      OpenCloset.alert 'danger', '방문 일자를 선택하기 전 성별을 먼저 선택해주세요.', '#visit-alert'
      return

    $('#modal-booking').modal()

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
      refreshExpectedFee()

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
    api: "/api/postcode/search.json"
    timeout: 10000    # 10 seconds
    hideOldAddresses: false
    insertDbid : ".postcodify_dbid"
    insertAddress : ".postcodify_address"
    insertJibeonAddress: ".postcodify_jibeonaddress"
    searchButtonContent: '주소검색'
    onReady: ->
      $("#postcodify").find('.postcodify_search_controls.postcode_search_controls')
        .addClass('input-group').find('input[type=text]')
        .prop('placeholder', "동과 번지수 혹은 아파트 이름")
        .addClass('form-control').val($('.postcodify_address').val()).end().find('button')
        .addClass('btn btn-default btn-sm')
        .wrap('<span class="input-group-btn"></span>')
    afterSelect: (selectedEntry) ->
      $("#postcodify").find('.postcodify_search_result.postcode_search_result')
        .remove()
    afterSearch: (keywords, results, lang, sort) ->
      $('summary.postcodify_search_status.postcode_search_status').hide()

  #
  # 예상대여비
  #
  refreshExpectedFee = (cost) ->
    if cost? and cost is 0
      return $('#expected-fee').data('expected-fee', cost).html ''

    expectedCost = cost or $('#expected-fee').data('expected-fee')
    return unless expectedCost

    wearon_ymd = $("input[name=wearon_date]").val()
    lateDay = 0
    if wearon_ymd
      wearonDate = new Date("#{wearon_ymd}T00:00:00")
      booking_ymd = $('#lbl-booking').text().trim()
      if booking_ymd
        booking_ymd = booking_ymd.substring(2, 12)
        bookingDate = new Date("#{booking_ymd}T00:00:00")
        duration = wearonDate.getTime() - bookingDate.getTime()
        durationDay = duration / (60 * 60 * 24 * 1000)
        lateDay = durationDay - 3 if durationDay > 3

    if lateDay
      $('#latefee-help').show()
      LATE_FEE_RATE = 0.2
      lateFee = expectedCost * lateDay * LATE_FEE_RATE
      $('#expected-fee').data('expected-fee', expectedCost).html """
        <samp>#{OpenCloset.commify(expectedCost + lateFee)}원 = #{OpenCloset.commify(expectedCost)}원 + #{OpenCloset.commify(lateFee)}원</samp>
        <br>
        <small class="text-muted">총대여비 = 기본대여비 + #{lateDay}일 추가연장비</small>
      """
    else
      $('#latefee-help').hide()
      $('#expected-fee').data('expected-fee', expectedCost).html """
        <samp>#{OpenCloset.commify(expectedCost)}원</samp>
        <small class="text-muted">총대여비</small>
      """

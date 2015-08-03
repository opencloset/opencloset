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
  )

  #
  # 대여 목적
  #
  purpose = $("select[name=purpose]").data('purpose')
  $("select[name=purpose]").chosen({ width: "100%" }).val(purpose).trigger("chosen:updated")

  #
  # SMS 인증하기 버튼 클릭
  #
  $('#btn-sms-confirm').click (e) ->
    e.preventDefault()

    name    = $("input[name=name]").val()
    phone   = $("input[name=phone]").val()

    if name && phone
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

  checkCancelBooking = () ->
    name          = $("input[name=name]").val()
    phone         = $("input[name=phone]").val()
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
    # 저장된 예약 아이디 점검
    #
    unless booking_saved
      OpenCloset.alert 'danger', '아직 예약한적이 없습니다.', '#visit-alert'
      return

    return true

  checkCreateOrUpdateBooking = () ->
    name    = $("input[name=name]").val()
    phone   = $("input[name=phone]").val()

    gender      = $("input[name=gender]:checked").val()
    email       = $("input[name=email]").val()
    address2    = $("input[name=address2]").val()
    birth       = $("input[name=birth]").val()
    booking     = $("input[name=booking]").val()
    wearon_date = $("input[name=wearon_date]").val()
    purpose     = $("select[name=purpose]").val()
    purpose2    = $("input[name=purpose2]").val()

    pre_category_temp = $("select[name=pre_category_temp]").val()
    pre_color1        = $("select[name=pre_color1]").val()
    pre_color2        = $("select[name=pre_color2]").val()

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
    # 상세 대여 목적 점검
    #
    unless purpose2
      OpenCloset.alert 'danger', '상세 대여 목적을 입력해주세요.', '#visit-alert'
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

    #
    # 두 번째 선호하는 색상 점검
    #
    unless pre_color2
      OpenCloset.alert 'danger', '두 번째 선호하는 색상을 입력해주세요.', '#visit-alert'
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
    gender         = $("input[name=gender]:checked").val()
    old_booking_id = $("input[name=booking]").prop("value")

    $.ajax "/api/gui/booking-list.json",
      type: 'GET'
      data:
        phone:  phone
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
        .prop('placeholder', "동과 번지수 혹은 동과 건물 이름")
        .addClass('form-control').val($('.postcodify_address').val()).end().find('button')
        .addClass('btn btn-default btn-sm')
        .wrap('<span class="input-group-btn"></span>')
    afterSelect: (selectedEntry) ->
      $("#postcodify").find('.postcodify_search_result.postcode_search_result')
        .remove()
    afterSearch: (keywords, results, lang, sort) ->
      $('summary.postcodify_search_status.postcode_search_status').hide()

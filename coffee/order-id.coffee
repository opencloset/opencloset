$ ->
  updateOrder = ->
    order_id = $('#order').data('order-id')
    $.ajax "/api/order/#{ order_id }.json",
      type: 'GET'
      success: (data, textStatus, jqXHR) ->
        $('#order').data('order-clothes-price',     data.clothes_price)
        $('#order').data('order-late-fee',          data.late_fee)
        $('#order').data('order-late-fee-discount', 0)
        $('#order').data('order-late-fee-final',    data.late_fee)
        $('#order').data('order-late-fee-pay-with', data.late_fee_pay_with)
        $('#order').data('order-overdue',           data.overdue)
        $('#order').data('order-parent-id',         data.parent_id)

        #
        # update price
        #
        $(".order-stage0-price").html( OpenCloset.commify(data.stage_price['0']) + '원' )
        $(".order-price").html( OpenCloset.commify(data.price) + '원' )
        $(".order-price-input").prop( 'value', data.price )

        #
        # update late_fee
        #
        compiled = _.template( $('#tpl-late-fee').html() )
        $("#late-fee").html( $(compiled(data)) )

        #
        # update late_fee discount
        #
        compiled = _.template( $('#tpl-late-fee-discount').html() )
        $("#late-fee-discount").html( $(compiled(data)) )
        $('#order-late-fee-discount').editable
          display: (value, sourceData, response) ->
            $(this).html( OpenCloset.commify value )
          success: (response, newValue) ->
            late_fee_discount = parseInt newValue
            late_fee_final    = data.late_fee + late_fee_discount
            $('.late-fee-final').html OpenCloset.commify(late_fee_final) + '원'
            $('#order').data('order-late-fee-discount', late_fee_discount)
            $('#order').data('order-late-fee-final',    late_fee_final)

        #
        # update late_fee final
        #
        if data.status_name is '대여중'
          $('.late-fee-final').html OpenCloset.commify(data.late_fee) + '원'
        else
          $('.late-fee-final').html OpenCloset.commify(data.stage_price['1']) + '원'
          $('.compensation-final').html OpenCloset.commify(data.stage_price['2']) + '원'

        #
        # update compensation final
        #
        $('#order-compensation').editable
          display: (value, sourceData, response) ->
            $(this).html( OpenCloset.commify value )
          success: (response, newValue) ->
            compensation          = parseInt newValue
            compensation_discount = parseInt $('#order-compensation-discount').editable( 'getValue', true )
            compensation_final    = compensation + compensation_discount

            $('#order').data('order-compensation', compensation)
            $('#order').data('order-compensation-discount', compensation_discount)
            $('#order').data('order-compensation-final', compensation_final)
            $('.compensation-final').html OpenCloset.commify(compensation_final) + '원'
        $('#order-compensation-discount').editable
          display: (value, sourceData, response) ->
            $(this).html( OpenCloset.commify value )
          success: (response, newValue) ->
            compensation          = parseInt $('#order-compensation').editable( 'getValue', true )
            compensation_discount = parseInt newValue
            compensation_final    = compensation + compensation_discount

            $('#order').data('order-compensation', compensation)
            $('#order').data('order-compensation-discount', compensation_discount)
            $('#order').data('order-compensation-final', compensation_final)
            $('.compensation-final').html OpenCloset.commify(compensation_final) + '원'
        #
        # update parcel tracking url
        #
        $('#parcel-tracking-url').attr('href', data.parcel)
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
  updateOrder()

  $('span.order-status.label').each (i, el) ->
    $(el).addClass OpenCloset.status[ $(el).data('order-detail-status') ].css

  $('#order-staff-name').editable()
  $('#order-additional-day').editable
    source:  -> { value: m, text: "#{m + 3}박 #{m + 4}일" } for m in [ 0 .. 20 ]
    success: (response, newValue) ->
      $(this).data('value', newValue)
      autoSetByAdditionalDay()
  $('#order-rental-date').editable
    mode:        'inline'
    showbuttons: 'true'
    type:        'combodate'
    emptytext:   '비어있음'

    format:      'YYYY-MM-DD'
    viewformat:  'YYYY-MM-DD'
    template:    'YYYY-MM-DD'

    combodate:
      minYear: 2013,
    url: (params) ->
      url = $('#order').data('url')
      data = {}
      data[params.name] = params.value
      $.ajax url,
        type: 'PUT'
        data: data
    success: (response, newValue) ->
      updateOrder()
  $('#order-target-date').editable
    mode:        'inline'
    showbuttons: 'true'
    type:        'combodate'
    emptytext:   '비어있음'

    format:      'YYYY-MM-DD'
    viewformat:  'YYYY-MM-DD'
    template:    'YYYY-MM-DD'

    combodate:
      minYear: 2013,
    url: (params) ->
      url = $('#order').data('url')
      data = {}
      data[params.name] = params.value + ' 23:59:59'
      $.ajax url,
        type: 'PUT'
        data: data
    success: (response, newValue) ->
      updateOrder()
  $('#order-user-target-date').editable
    mode:        'inline'
    showbuttons: 'true'
    type:        'combodate'
    emptytext:   '비어있음'

    format:      'YYYY-MM-DD'
    viewformat:  'YYYY-MM-DD'
    template:    'YYYY-MM-DD'

    combodate:
      minYear: 2013,
    url: (params) ->
      url = $('#order').data('url')
      data = {}
      data[params.name] = params.value + ' 23:59:59'
      $.ajax url,
        type: 'PUT'
        data: data
  $('#order-price-pay-with').editable
    source: -> { value: m, text: m } for m in OpenCloset.payWith
  $('#order-late-fee-pay-with').editable
    source: -> { value: m, text: m } for m in OpenCloset.payWith
    success: (response, newValue) ->
      $('#order').data('order-late-fee-pay-with', newValue)
  $('#order-compensation-pay-with').editable
    source: -> { value: m, text: m } for m in OpenCloset.payWith
    success: (response, newValue) ->
      $('#order').data('order-compensation-pay-with', newValue)
  $('#order-bestfit').editable
    source: -> { value: k, text: v } for k, v of { 0: '보통', 1: 'Best-Fit' }
  $('.order-detail').editable()

  setOrderDetailFinalPrice = (order_detail_id) ->
    is_clothes  = $("#order-detail-price-#{ order_detail_id }").data('is-clothes')
    is_pre_paid = $("#order-detail-price-#{ order_detail_id }").data('is-pre-paid')
    day         = parseInt $('#order-additional-day').data('value')
    price       = parseInt $("#order-detail-price-#{ order_detail_id }").data('value')

    return if is_pre_paid

    if is_clothes
      final_price = price + price * 0.2 * day
    else
      final_price = price * day
    $( "#order-detail-final-price-#{ order_detail_id }" ).editable 'setValue', final_price
    $( "#order-detail-final-price-#{ order_detail_id }" ).editable 'submit'

  $('.order-detail-price').each (i, el) ->
    $(el).editable
      display: (value, sourceData, response) ->
        $(this).html( OpenCloset.commify value )
      success: (response, newValue) ->
        $(el).data('value', newValue)
        updateOrder()
        setOrderDetailFinalPrice $(el).data('pk')

  $('#order-desc').editable()

  $('.order-detail-final-price').editable
    display: (value, sourceData, response) -> $(this).html( OpenCloset.commify value )
    success: (response, newValue) -> updateOrder()

  $('#btn-order-clear').click (e) ->
    order_id = $('#order').data('order-id')
    $.ajax "/api/order/#{ order_id }/set-package.json",
      type: 'GET'
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        window.location.assign "/order?status=19"

  $('#btn-order-confirm').click (e) ->
    order_id     = $('#order').data('order-id')
    url          = $(e.target).data('url')
    redirect_url = $(e.target).data('redirect-url')

    return unless url
    return unless order_id

    $.ajax "/api/order/#{ order_id }.json",
      type: 'GET'
      success: (data, textStatus, jqXHR) ->
        unless data.staff_id
          OpenCloset.alert 'danger', '담당자를 입력하세요.'
          return
        unless data.additional_day >= 0
          OpenCloset.alert 'danger', '대여 기간을 입력하세요.'
          return
        unless data.rental_date
          OpenCloset.alert 'danger', '대여일을 입력하세요.'
          return
        unless data.target_date
          OpenCloset.alert 'danger', '반납 예정일을 입력하세요.'
          return
        unless data.price_pay_with
          OpenCloset.alert 'danger', '대여비 납부 여부를 확인하세요.'
          return

        $.ajax url,
          type: 'POST'
          data:
            id:    order_id
            name:  'status_id'
            value: 2
            pk:    order_id
          success: (data, textStatus, jqXHR) ->
            $.ajax $(e.target).data('monitor-url'),
              type: 'POST'
              data:
                sender:   'order'
                order_id: order_id
                from:     19    # 결제대기
                to:       2     # 대여중
              success: ->
              error: (jqXHR, textStatus, errorThrown) ->
                OpenCloset.alert 'danger', '모니터 이벤트 전송에 실패했습니다.'
              complete: (jqXHR, textStatus) ->
                window.location.href = redirect_url
          error: (jqXHR, textStatus, errorThrown) ->
            OpenCloset.alert 'danger', '주문서 상태 변경에 실패했습니다.'
          complete: (jqXHR, textStatus) ->
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->

  autoSetByAdditionalDay = ->
    return if $('#order-additional-day').data('disabled')

    day = parseInt $('#order-additional-day').data('value')

    parent_id = parseInt $('#order').data('order-parent-id')
    if parent_id
      rental_date = $('#order-rental-date').editable 'getValue', true
      new_date    = moment(rental_date).add('days', day + 3).endOf('day')

      # 반납 예정일을 대여일을 기준으로 자동으로 계산
      $('#order-target-date').editable 'setValue', new_date.format('YYYY-MM-DD HH:mm:ss'), true
      $('#order-target-date').editable 'submit'

      # 반납 희망일을 대여일을 기준으로 자동으로 계산
      $('#order-user-target-date').editable 'setValue', new_date.format('YYYY-MM-DD HH:mm:ss'), true
      $('#order-user-target-date').editable 'submit'
    else
      # 대여일을 오늘로 자동 설정
      $('#order-rental-date').editable 'setValue', moment().format('YYYY-MM-DD HH:mm:ss'), true
      $('#order-rental-date').editable 'submit'

      # 반납 예정일을 오늘을 기준으로 자동으로 계산
      $('#order-target-date').editable 'setValue', moment().add('days', day + 3).endOf('day').format('YYYY-MM-DD HH:mm:ss'), true
      $('#order-target-date').editable 'submit'

      # 반납 희망일을 오늘을 기준으로 자동으로 계산
      $('#order-user-target-date').editable 'setValue', moment().add('days', day + 3).endOf('day').format('YYYY-MM-DD HH:mm:ss'), true
      $('#order-user-target-date').editable 'submit'

    # 주문표의 대여일을 자동 설정
    $('#order table td:nth-child(6) span').html( "4+#{ day }일" )

    # 주문표의 소계를 자동 설정
    $('.order-detail-price').each (i, el) ->
      setOrderDetailFinalPrice $(el).data('pk')

  autoSetByAdditionalDay()

  #
  # 환불 진행 버튼 클릭
  #
  $('#btn-refund-process').click (e) ->
    $('#order-refund-error').html('')
    $('#order-refund-charge').prop 'value', 0
    $('#order-refund-real').prop 'value', 0
    $("#modal-refund").modal('show')
  $("#btn-refund-modal-cancel").click (e) ->
    $("#modal-refund").modal('hide')
  $("#btn-refund-modal-ok").click (e) ->
    total  = parseInt( $('#order-refund-total').prop 'value' )
    charge = parseInt( $('#order-refund-charge').prop 'value' )
    real   = parseInt( $('#order-refund-real').prop 'value' )
    unless total is charge + real
      $('#order-refund-error').html('환불 수수료와 환불 금액의 합이 주문서 총액과 일치하지 않습니다.')
      return
    $("#modal-refund").modal('hide')
    #
    # 환불 금액 항목 추가
    #
    order_id = $('#order').data('order-id')
    $.ajax "/api/order_detail.json",
      type: 'POST'
      data: {
        order_id:    order_id
        name:        '환불'
        price:       -real
        final_price: -real
        desc:        "환불 수수료: #{charge}원"
        stage:       3
      }
    returnClothesReal 'refund', "/order/#{order_id}", order_id, '미납', '미납'

  #
  # 반납 진행 버튼 클릭
  #
  $('#btn-return-process').click (e) ->
    $(".return-process input[data-clothes-code]").prop 'checked', 0
    $('.return-process').show()
    $('.return-process-reverse').hide()
    $('#clothes-search').val('').focus()
    $('#order-late-fee-pay-with').editable 'enable'

  #
  # 반납 취소 버튼 클릭
  #
  $('#btn-return-cancel').click (e) ->
    $(".return-process input[data-clothes-code]").prop 'checked', 0
    $('.return-process').hide()
    $('.return-process-reverse').show()
    $('#order-late-fee-pay-with').editable 'disable'
    $('#order-late-fee-pay-with').editable 'setValue', ''
    $('#order-late-fee-pay-with').html '미납'

  returnClothesReal = (type, redirect_url, order_id, late_fee_pay_with, compensation_pay_with) ->
    if type is 'part'
      #
      # 부분 반납
      #
      order_detail_id = []
      $("input[data-clothes-code]").each (i, el) ->
        return unless $(el).prop 'checked'
        order_detail_id.push $(el).data('id')

      url  = "/api/order/#{ order_id }/return-part.json"
      data =
        status_id:              9
        return_date:            moment().format('YYYY-MM-DD HH:mm:ss')
        return_method:          '직접방문'
        late_fee_pay_with:      late_fee_pay_with
        order_detail_id:        order_detail_id
    else if type is 'refund'
      #
      # 환불
      #
      order_detail_id = []
      $("input[data-clothes-code]").each (i, el) -> order_detail_id.push $(el).data('id')
      order_detail_status_id = ( 42 for code in order_detail_id )

      url  = "/api/order/#{ order_id }.json"
      data =
        status_id:              42
        return_date:            moment().format('YYYY-MM-DD HH:mm:ss')
        return_method:          '직접방문'
        late_fee_pay_with:      late_fee_pay_with
        compensation_pay_with:  compensation_pay_with
        order_detail_id:        order_detail_id
        order_detail_status_id: order_detail_status_id
    else
      #
      # 최종 반납
      #
      order_detail_id = []
      $("input[data-clothes-code]").each (i, el) -> order_detail_id.push $(el).data('id')
      order_detail_status_id = ( 9 for code in order_detail_id )

      url  = "/api/order/#{ order_id }.json"
      data =
        status_id:              9
        return_date:            moment().format('YYYY-MM-DD HH:mm:ss')
        return_method:          '직접방문'
        late_fee_pay_with:      late_fee_pay_with
        compensation_pay_with:  compensation_pay_with
        order_detail_id:        order_detail_id
        order_detail_status_id: order_detail_status_id
    $.ajax url,
      type:    'PUT'
      data:    $.param(data, 1)
      success: (data, textStatus, jqXHR) ->
        #
        # 주문서 페이지 리로드
        #
        window.location.href = redirect_url

  returnOrder = (type, redirect_url) ->
    order_id              = $('#order').data('order-id')
    clothes_price         = $('#order').data('order-clothes-price')
    late_fee              = $('#order').data('order-late-fee')
    late_fee_discount     = $('#order').data('order-late-fee-discount')
    late_fee_final        = $('#order').data('order-late-fee-final')
    late_fee_pay_with     = $('#order').data('order-late-fee-pay-with')
    compensation          = $('#order').data('order-compensation')          || 0
    compensation_discount = $('#order').data('order-compensation-discount') || 0
    compensation_final    = $('#order').data('order-compensation-final')    || 0
    compensation_pay_with = $('#order').data('order-compensation-pay-with')
    overdue               = $('#order').data('order-overdue')

    if late_fee_final != 0 and not late_fee_pay_with
      OpenCloset.alert 'danger', '연체료를 납부받지 않았습니다.'
      return

    if compensation == 0 and compensation_discount != 0
      OpenCloset.alert 'danger', '배상비 없이 배상비 에누리가 있을 수 없습니다.'
      return

    if compensation_final != 0 and not compensation_pay_with
      OpenCloset.alert 'danger', '배상비를 납부받지 않았습니다.'
      return

    #
    # 연체료 항목 추가
    #
    $.ajax "/api/order_detail.json",
      type: 'POST'
      data: {
        order_id:    order_id
        name:        '연체료'
        price:       clothes_price * 0.2
        final_price: late_fee
        stage:       1
        desc:        "#{OpenCloset.commify clothes_price}원 x 20% x #{overdue}일"
      }
      complete: (jqXHR, textStatus) ->
        #
        # 연체료 에누리 항목 추가
        #
        if late_fee_discount != 0
          $.ajax "/api/order_detail.json",
            type: 'POST'
            data: {
              order_id:    order_id
              name:        '연체료 에누리'
              price:       Math.round( late_fee_discount / overdue )
              final_price: late_fee_discount
              stage:       1
            }

    #
    # 배상비 항목 추가
    #
    if compensation != 0
      $.ajax "/api/order_detail.json",
        type: 'POST'
        data: {
          order_id:    order_id
          name:        '배상비'
          price:       compensation
          final_price: compensation
          stage:       2
        }
        complete: (jqXHR, textStatus) ->
          #
          # 배상비 에누리 항목 추가
          #
          if compensation_discount != 0
            $.ajax "/api/order_detail.json",
              type: 'POST'
              data: {
                order_id:    order_id
                name:        '배상비 에누리'
                price:       compensation_discount
                final_price: compensation_discount
                stage:       2
              }

    returnClothesReal type, redirect_url, order_id, late_fee_pay_with, compensation_pay_with

  #
  # 전체 반납 버튼 클릭
  #
  $('#btn-return-all').click (e) ->
    redirect_url = $(e.target).data('redirect-url')
    count        = countSelectedOrderDetail()
    unless count.selected > 0 && count.selected is count.total
      OpenCloset.alert 'error', "반납할 항목을 선택하지 않았습니다."
      return
    returnOrder 'all', redirect_url

  #
  # 부분 반납 버튼 클릭
  #
  $('#btn-return-part').click (e) ->
    redirect_url = $(e.target).data('redirect-url')
    count        = countSelectedOrderDetail()
    unless count.selected > 0
      OpenCloset.alert 'error', "반납할 항목을 선택하지 않았습니다."
      return
    returnOrder 'part', redirect_url

  #
  # 주문서 목록에서 선택된 항목과 선택할 수 있는 항목 총 개수를 반환
  #
  countSelectedOrderDetail = ->
    selected = 0
    total = 0
    $(".return-process input[data-clothes-code]").each (i, el) ->
      ++selected if $(el).prop 'checked'
      ++total
    { selected: selected, total: total }

  #
  # 부분 반납 및 전체 반납 여부에 따라
  #   - 부분 반납 및 전체 반납 버튼 활성 또는 비활성화
  #   - 배상비 항목 활성 또는 비활성화
  #
  refreshReturnButton = ->
    count = countSelectedOrderDetail()
    enable_compensation = 0
    if count.selected > 0
      if count.selected is count.total
        $('#btn-return-all').removeClass('disabled')
        $('#btn-return-part').addClass('disabled')
        ++enable_compensation
      else
        $('#btn-return-all').addClass('disabled')
        $('#btn-return-part').removeClass('disabled')
    else
      $('#btn-return-all').addClass('disabled')
      $('#btn-return-part').addClass('disabled')

    if enable_compensation
      $('#order-compensation').editable 'enable'
      $('#order-compensation-discount').editable 'enable'
      $('#order-compensation-pay-with').editable 'enable'
    else
      $('#order-compensation').editable 'disable'
      $('#order-compensation').editable 'setValue', '0'
      $('#order-compensation-discount').editable 'disable'
      $('#order-compensation-discount').editable 'setValue', '0'
      $('#order-compensation-pay-with').editable 'disable'
      $('#order-compensation-pay-with').editable 'setValue', ''
      $('#order-compensation-pay-with').html '미납'

  #
  # 주문서 목록의 체크박스 클릭시 반납 버튼 활성화 여부 갱신
  #
  $(".return-process input[data-clothes-code]").click -> refreshReturnButton()

  #
  # 검색한 의류 품번에 일치하는 주문서 목록의 체크박스에 체크
  #
  selectSearchedClothes = ->
    clothes_code = OpenCloset.trimClothesCode $('#clothes-search').val().toUpperCase()
    $('#clothes-search').val('').focus()
    $(".return-process input[data-clothes-code=#{ clothes_code }]").click()
    refreshReturnButton()

  #
  # 반납용 의류 품번 검색시 동작
  #
  $('#clothes-search').keypress (e) -> $('#btn-clothes-search').click() if e.keyCode is 13
  $('#btn-clothes-search').click -> selectSearchedClothes()

  $('#order-return-method').editable
    mode:      'inline'
    emptytext: '비어있음'
    source:    ['대한통운', 'Yellowcap']
    url: (params) ->
      url = $('#order').data('url')
      data = {}
      value = params.value
      data[params.name] = "#{value.parcel},#{value.number}"
      $.ajax url,
        type: 'PUT'
        data: data
        success: ->
          $.ajax "#{$('#order').data('url')}.json",
            type: 'GET'
            success: (data, textStatus, jqXHR) ->
              $('#parcel-tracking-url').attr('href', data.parcel)

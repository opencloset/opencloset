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

        #
        # update price
        #
        $(".order-stage0-price").html( OpenCloset.commify(data.stage0_price) + '원' )
        $(".order-price").html( OpenCloset.commify(data.price) + '원' )

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
            $('.late-fee-final').html OpenCloset.commify(late_fee_final)
            $('#order').data('order-late-fee-discount', late_fee_discount)
            $('#order').data('order-late-fee-final',    late_fee_final)

        #
        # update late_fee final
        #
        if data.price is data.stage0_price
          $('.late-fee-final').html OpenCloset.commify(data.late_fee) + '원'
        else
          $('.late-fee-final').html OpenCloset.commify(data.price - data.stage0_price) + '원'
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
  $('#order-price-pay-with').editable
    source: -> { value: m, text: m } for m in [ '현금', '카드', '현금+카드' ]
  $('#order-late-fee-pay-with').editable
    source: -> { value: m, text: m } for m in [ '현금', '카드', '현금+카드' ]
    success: (response, newValue) ->
      $('#order').data('order-late-fee-pay-with', newValue)
  $('.order-detail').editable()

  setOrderDetailFinalPrice = (order_detail_id) ->
    is_clothes  = $("#order-detail-price-#{ order_detail_id }").data('is-clothes')
    day         = parseInt $('#order-additional-day').data('value')
    price       = parseInt $("#order-detail-price-#{ order_detail_id }").data('value')
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
          alert 'danger', '담당자를 입력하세요.'
          return
        unless data.additional_day >= 0
          alert 'danger', '대여 기간을 입력하세요.'
          return
        unless data.rental_date
          alert 'danger', '대여일을 입력하세요.'
          return
        unless data.target_date
          alert 'danger', '반납 예정일을 입력하세요.'
          return
        unless data.price_pay_with
          alert 'danger', '대여비 납부 여부를 확인하세요.'
          return

        $.ajax url,
          type: 'POST'
          data: {
            id:    order_id
            name:  'status_id'
            value: 2
            pk:    order_id
          }
          success: (data, textStatus, jqXHR) ->
            window.location.href = redirect_url
          error: (jqXHR, textStatus, errorThrown) ->
            alert 'danger', jqXHR.responseJSON.error
          complete: (jqXHR, textStatus) ->
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->

  autoSetByAdditionalDay = ->
    return if $('#order-additional-day').data('disabled')

    day = parseInt $('#order-additional-day').data('value')

    # 대여일을 오늘로 자동 설정
    $('#order-rental-date').editable 'setValue', moment().format('YYYY-MM-DD HH:mm:ss'), true
    $('#order-rental-date').editable 'submit'

    # 반납 예정일을 오늘을 기준으로 자동으로 계산
    $('#order-target-date').editable 'setValue', moment().add('days', day + 3).endOf('day').format('YYYY-MM-DD HH:mm:ss'), true
    $('#order-target-date').editable 'submit'

    # 주문표의 대여일을 자동 설정
    $('#order table td:nth-child(6) span').html( "4+#{ day }일" )

    # 주문표의 소계를 자동 설정
    $('.order-detail-price').each (i, el) ->
      setOrderDetailFinalPrice $(el).data('pk')

  autoSetByAdditionalDay()

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

  #
  # 전체 반납 버튼 클릭
  #
  $('#btn-return-all').click (e) ->
    redirect_url = $(e.target).data('redirect-url')

    count = countSelectedOrderDetail()
    unless count.selected > 0 && count.selected is count.total
      alert 'error', "반납할 항목을 선택하지 않았습니다."
      return

    order_id          = $('#order').data('order-id')
    clothes_price     = $('#order').data('order-clothes-price')
    late_fee          = $('#order').data('order-late-fee')
    late_fee_discount = $('#order').data('order-late-fee-discount')
    late_fee_final    = $('#order').data('order-late-fee-final')
    late_fee_pay_with = $('#order').data('order-late-fee-pay-with')
    overdue           = $('#order').data('order-overdue')

    order_detail_id = []
    $("input[data-clothes-code]").each (i, el) -> order_detail_id.push $(el).data('id')

    order_detail_status_id = ( 9 for code in order_detail_id )

    if late_fee_final > 0 and not late_fee_pay_with
      alert 'danger', '연체료를 납부받지 않았습니다.'
      return

    #
    # 연체료, 연체료 에누리 항목 추가
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
      success: (data, textStatus, jqXHR) ->
        $.ajax "/api/order_detail.json",
          type: 'POST'
          data: {
            order_id:    order_id
            name:        '연체료 에누리'
            price:       Math.round( late_fee_discount / overdue )
            final_price: late_fee_discount
            stage:       1
          }
          success: (data, textStatus, jqXHR) ->
            #
            # 최종 반납
            #
            data =
              status_id:              9
              return_date:            moment().format('YYYY-MM-DD HH:mm:ss')
              return_method:          '직접방문'
              late_fee_pay_with:      late_fee_pay_with
              order_detail_id:        order_detail_id
              order_detail_status_id: order_detail_status_id
            $.ajax "/api/order/#{ order_id }.json",
              type:    'PUT'
              data:    $.param(data, 1)
              success: (data, textStatus, jqXHR) ->
                #
                # 주문서 페이지 리로드
                #
                window.location.href = redirect_url

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
  # 부분 반납 및 전체 반납 버튼 활성 또는 비활성화
  #
  refreshReturnButton = ->
    count = countSelectedOrderDetail()
    if count.selected > 0
      if count.selected is count.total
        $('#btn-return-all').removeClass('disabled')
        $('#btn-return-part').addClass('disabled')
      else
        $('#btn-return-all').addClass('disabled')
        $('#btn-return-part').removeClass('disabled')
    else
      $('#btn-return-all').addClass('disabled')
      $('#btn-return-part').addClass('disabled')

  #
  # 주문서 목록의 체크박스 클릭시 반납 버튼 활성화 여부 갱신
  #
  $(".return-process input[data-clothes-code]").click -> refreshReturnButton()

  #
  # 검색한 의류 품번에 일치하는 주문서 목록의 체크박스에 체크
  #
  selectSearchedClothes = ->
    clothes_code = OpenCloset.trimClothesCode $('#clothes-search').val()
    $('#clothes-search').val('').focus()
    $(".return-process input[data-clothes-code=#{ clothes_code }]").click()
    refreshReturnButton()

  #
  # 반납용 의류 품번 검색시 동작
  #
  $('#clothes-search').keypress (e) -> $('#btn-clothes-search').click() if e.keyCode is 13
  $('#btn-clothes-search').click -> selectSearchedClothes()

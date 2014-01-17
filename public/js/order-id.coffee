$ ->
  updateOrder = ->
    order_id = $('#order').data('order-id')
    $.ajax "/api/order/#{ order_id }.json",
      type: 'GET'
      success: (data, textStatus, jqXHR) ->
        #
        # update price
        #
        $(".order-price").html( OpenCloset.commify(data.price) + '원' )

        #
        # update late_fee
        #
        compiled = _.template( $('#tpl-late-fee').html() )
        $("#late-fee").html( $(compiled(data)) )

        $('#order-late-fee-pay-with').editable
          source: -> { value: m, text: m } for m in [ '현금', '카드', '현금+카드' ]
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
  $('.order-detail').editable()

  setOrderDetailFinalPrice = (order_detail_id) ->
    day         = parseInt $('#order-additional-day').data('value')
    price       = parseInt $("#order-detail-price-#{ order_detail_id }").data('value')
    final_price = price + price * 0.2 * day
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
            alert('danger', jqXHR.responseJSON.error)
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
    $('#order table td:nth-child(5) span').html( "4+#{ day }일" )

    # 주문표의 소계를 자동 설정
    $('.order-detail-price').each (i, el) ->
      setOrderDetailFinalPrice $(el).data('pk')

  autoSetByAdditionalDay()

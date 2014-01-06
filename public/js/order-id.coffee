$ ->
  $('span.order-status.label').each (i, el) ->
    $(el).addClass( OpenCloset.getStatusCss $(el).data('order-detail-status') )
    if $(el).data('order-detail-status') is '대여중' && $(el).data('order-late-fee') > 0
      $(el).html('연체중')

  $('#order-staff-name').editable()
  $('#order-rental-date').editable({
    combodate: {
       minYear: 2014,
    }
  })
  $('#order-target-date').editable({
    combodate: {
       minYear: 2014,
    }
  })
  $('#order-payment-method').editable({
    source: ->
      result = []
      for m in [ '현금', '카드', '현금+카드' ]
        result.push { value: m, text: m }
      return result
  })
  $('.order-detail').editable()

  $('#btn-order-confirm').click (e) ->
    url          = $(e.target).data('url')
    order_id     = $(e.target).data('order-id')
    redirect_url = $(e.target).data('redirect-url')

    return unless url
    return unless order_id

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
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->

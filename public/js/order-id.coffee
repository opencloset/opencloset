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

        $('#order-late-fee-pay-with').editable({
          source: ->
            result = []
            for m in [ '현금', '카드', '현금+카드' ]
              result.push { value: m, text: m }
            return result
        })
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
  updateOrder()

  $('span.order-status.label').each (i, el) ->
    $(el).addClass( OpenCloset.getStatusCss $(el).data('order-detail-status') )

  $('#order-staff-name').editable()
  $('#order-rental-date').editable({
    combodate:
     minYear: 2013,
  })
  $('#order-target-date').editable({
    combodate:
     minYear: 2013,
    success: (response, newValue) ->
      updateOrder()
  })
  $('#order-price-pay-with').editable({
    source: ->
      result = []
      for m in [ '현금', '카드', '현금+카드' ]
        result.push { value: m, text: m }
      return result
  })
  $('.order-detail').editable()
  $('.order-detail-discount').editable({
    display: (value, sourceData, response) ->
      $(this).html( OpenCloset.commify value )
    success: (response, newValue) ->
      updateOrder()
  })
  $('#order-desc').editable()

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

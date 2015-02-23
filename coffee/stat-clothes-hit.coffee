$ ->
  $('span.category').each (i, el) ->
    $(el).html OpenCloset.category[ $(el).data('category') ].str

  $("#start_date").datepicker(
    todayHighlight: true
    autoclose:      true
  )

  $("#end_date").datepicker(
    todayHighlight: true
    autoclose:      true
  )

  $('#btn-hit-search').click (e) ->
    start_date  = $('input[name=start_date]').prop('value')
    end_date    = $('input[name=end_date]').prop('value')
    category    = $("select[name=category]").val()
    limit       = $('input[name=limit]').prop('value')

    unless /^\d+$/.test( limit )
      OpenCloset.alert 'danger', '유효하지 않은 입력값입니다.'
      $('input[name=limit]').focus()
      return

    window.location = "/stat/clothes/hit/#{category}?#{$.param({ start_date: start_date, end_date: end_date, limit: limit})}"

$ ->
  $('span.category').each (i, el) ->
    $(el).html OpenCloset.category[ $(el).data('category') ].str

  $('span.color').each (i, el) ->
    $(el).html OpenCloset.color[ $(el).data('color') ]

  $("#start_date").datepicker(
    todayHighlight: true
    autoclose:      true
  )

  $("#end_date").datepicker(
    todayHighlight: true
    autoclose:      true
  )

  $('#btn-hit-search').click (e) ->
    start_date  = $("#start_date").val()
    end_date    = $("#end_date").val()
    category    = $("select[name=category]").val()
    gender      = $("select[name=gender]").val()
    limit       = $("#limit").prop("value")

    unless /^\d+$/.test( limit )
      OpenCloset.alert 'danger', '유효하지 않은 입력값입니다.'
      $('input[name=limit]').focus()
      return

    window.location = "/stat/clothes/hit/#{category}?#{$.param({ start_date: start_date, end_date: end_date, gender: gender, limit: limit })}"

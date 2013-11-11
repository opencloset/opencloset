$ ->
  #
  # step1 - 기증자 검색과 기증자 선택을 연동합니다.
  #
  add_registered_giver = ->
    query = $('#giver-search').val()

    # sample data - TODO get real data using ajax
    data =
      giver_id: query.length,
      giver_name: query,

    return unless query
    return if     $("#giver-search-list input[data-giver-id='#{data.giver_id}']").length

    compiled = _.template($('#tpl-new-cloth-giver-id').html())
    html = $(compiled(data))
    $("#giver-search-list").append(html)

  $('#giver-search').keypress (e) -> add_registered_giver() if e.keyCode is 13
  $('#btn-giver-search').click -> add_registered_giver()

  #
  # step2 - 의류 종류 선택 콤보박스
  #
  $('#display-cloth-bust').show()
  $('#display-cloth-waist').show()
  $('#display-cloth-arm').show()
  $('#display-cloth-leg').show()
  $('#display-cloth-foot').show()

  $('#cloth-bust').prop('disabled', true)
  $('#cloth-waist').prop('disabled', true)
  $('#cloth-arm').prop('disabled', true)
  $('#cloth-leg').prop('disabled', true)
  $('#cloth-foot').prop('disabled', true)

  $("#cloth-type").select2()
    .on 'change', (e) ->
      switch e.val
        when "-1", "-2", "9"
          $('#display-cloth-bust').show()
          $('#display-cloth-waist').show()
          $('#display-cloth-arm').show()
          $('#display-cloth-leg').show()
          $('#display-cloth-foot').hide()

          $('#cloth-bust').prop('disabled', false)
          $('#cloth-waist').prop('disabled', false)
          $('#cloth-arm').prop('disabled', false)
          $('#cloth-leg').prop('disabled', false)
          $('#cloth-foot').prop('disabled', true)
        when "1", "7", "8"
          $('#display-cloth-bust').show()
          $('#display-cloth-waist').show()
          $('#display-cloth-arm').show()
          $('#display-cloth-leg').hide()
          $('#display-cloth-foot').hide()

          $('#cloth-bust').prop('disabled', false)
          $('#cloth-waist').prop('disabled', false)
          $('#cloth-arm').prop('disabled', false)
          $('#cloth-leg').prop('disabled', true)
          $('#cloth-foot').prop('disabled', true)
        when "3", "11"
          $('#display-cloth-bust').show()
          $('#display-cloth-waist').show()
          $('#display-cloth-arm').show()
          $('#display-cloth-leg').hide()
          $('#display-cloth-foot').hide()

          $('#cloth-bust').prop('disabled', false)
          $('#cloth-waist').prop('disabled', false)
          $('#cloth-arm').prop('disabled', false)
          $('#cloth-leg').prop('disabled', true)
          $('#cloth-foot').prop('disabled', true)
        when "2", "10"
          $('#display-cloth-bust').hide()
          $('#display-cloth-waist').show()
          $('#display-cloth-arm').hide()
          $('#display-cloth-leg').show()
          $('#display-cloth-foot').hide()

          $('#cloth-bust').prop('disabled', true)
          $('#cloth-waist').prop('disabled', false)
          $('#cloth-arm').prop('disabled', true)
          $('#cloth-leg').prop('disabled', fase)
          $('#cloth-foot').prop('disabled', true)
        when "4"
          $('#display-cloth-bust').hide()
          $('#display-cloth-waist').hide()
          $('#display-cloth-arm').hide()
          $('#display-cloth-leg').hide()
          $('#display-cloth-foot').show()

          $('#cloth-bust').prop('disabled', true)
          $('#cloth-waist').prop('disabled', true)
          $('#cloth-arm').prop('disabled', true)
          $('#cloth-leg').prop('disabled', true)
          $('#cloth-foot').prop('disabled', false)
        when "5", "6"
          $('#display-cloth-bust').hide()
          $('#display-cloth-waist').hide()
          $('#display-cloth-arm').hide()
          $('#display-cloth-leg').hide()
          $('#display-cloth-foot').hide()

          $('#cloth-bust').prop('disabled', true)
          $('#cloth-waist').prop('disabled', true)
          $('#cloth-arm').prop('disabled', true)
          $('#cloth-leg').prop('disabled', true)
          $('#cloth-foot').prop('disabled', true)
        else
          $('#display-cloth-bust').hide()
          $('#display-cloth-waist').hide()
          $('#display-cloth-arm').hide()
          $('#display-cloth-leg').hide()
          $('#display-cloth-foot').hide()

          $('#cloth-bust').prop('disabled', true)
          $('#cloth-waist').prop('disabled', true)
          $('#cloth-arm').prop('disabled', true)
          $('#cloth-leg').prop('disabled', true)
          $('#cloth-foot').prop('disabled', true)

  #
  # 마법사 위젯
  #
  validation = false
  $('#fuelux-wizard').ace_wizard()
    .on 'change', (e, info) ->
      if info.step is 1 && validation
        return false unless $('#validation-form').valid()
    .on 'finished', (e) ->
      false
    .on 'stepclick', (e) ->
      #false

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
  $("#cloth-type").select2()
    .on 'change', (e) ->
      switch e.val
        when "-1", "-2", "9"
          $('#display-cloth-bust').show()
          $('#display-cloth-waist').show()
          $('#display-cloth-arm').show()
          $('#display-cloth-leg').show()
          $('#display-cloth-foot').hide()
        when "1", "7", "8"
          $('#display-cloth-bust').show()
          $('#display-cloth-waist').show()
          $('#display-cloth-arm').show()
          $('#display-cloth-leg').hide()
          $('#display-cloth-foot').hide()
        when "3", "11"
          $('#display-cloth-bust').show()
          $('#display-cloth-waist').show()
          $('#display-cloth-arm').show()
          $('#display-cloth-leg').hide()
          $('#display-cloth-foot').hide()
        when "2", "10"
          $('#display-cloth-bust').hide()
          $('#display-cloth-waist').show()
          $('#display-cloth-arm').hide()
          $('#display-cloth-leg').show()
          $('#display-cloth-foot').hide()
        when "4"
          $('#display-cloth-bust').hide()
          $('#display-cloth-waist').hide()
          $('#display-cloth-arm').hide()
          $('#display-cloth-leg').hide()
          $('#display-cloth-foot').show()
        when "5", "6"
          $('#display-cloth-bust').hide()
          $('#display-cloth-waist').hide()
          $('#display-cloth-arm').hide()
          $('#display-cloth-leg').hide()
          $('#display-cloth-foot').hide()
        else
          $('#display-cloth-bust').hide()
          $('#display-cloth-waist').hide()
          $('#display-cloth-arm').hide()
          $('#display-cloth-leg').hide()
          $('#display-cloth-foot').hide()

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

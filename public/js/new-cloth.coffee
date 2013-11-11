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
    $('#giver-search-list').append(html)

  $('#giver-search').keypress (e) -> add_registered_giver() if e.keyCode is 13
  $('#btn-giver-search').click -> add_registered_giver()

  #
  # step3 - 의류 종류 선택 콤보박스
  #
  clear_cloth_form = (show) ->
    if show
      $('#display-cloth-bust').show()
      $('#display-cloth-waist').show()
      $('#display-cloth-hip').show()
      $('#display-cloth-arm').show()
      $('#display-cloth-length').show()
      $('#display-cloth-foot').show()
    else
      $('#display-cloth-bust').hide()
      $('#display-cloth-waist').hide()
      $('#display-cloth-hip').hide()
      $('#display-cloth-arm').hide()
      $('#display-cloth-length').hide()
      $('#display-cloth-foot').hide()

    $('#cloth-bust').prop('disabled', true)
    $('#cloth-waist').prop('disabled', true)
    $('#cloth-hip').prop('disabled', true)
    $('#cloth-arm').prop('disabled', true)
    $('#cloth-length').prop('disabled', true)
    $('#cloth-foot').prop('disabled', true)

    $('#cloth-color').select2('val', '')
    $('#cloth-bust').val('')
    $('#cloth-waist').val('')
    $('#cloth-hip').val('')
    $('#cloth-arm').val('')
    $('#cloth-length').val('')
    $('#cloth-foot').val('')

  $('#cloth-type').select2( dropdownCssClass: 'bigdrop' )
    .on 'change', (e) ->
      clear_cloth_form false
      types = []
      switch e.val
        when '-1'                then types = [ 'bust', 'arm', 'waist', 'length'        ] # Jacket & Pants
        when '-2'                then types = [ 'bust', 'arm', 'waist', 'hip', 'length' ] # Jacket & Skirts
        when '1', '3', '8', '11' then types = [ 'bust', 'arm'                           ] # Jacket, Shirts, Coat, Blouse
        when '2'                 then types = [ 'waist', 'length'                       ] # Pants
        when '10'                then types = [ 'waist', 'hip', 'length'                ] # Skirt
        when '4'                 then types = [ 'foot'                                  ] # Shoes
        when '7'                 then types = [ 'waist'                                 ] # Waistcoat
        when '5', '6', '9'       then types = [                                         ] # Hat, Tie, Onepiece
        else                          types = [                                         ]
      for type in types
        $("#display-cloth-#{type}").show()
        $("#cloth-#{type}").prop('disabled', false)
  $('#cloth-color').select2()

  $('#cloth-type').select2('val', '')
  clear_cloth_form true

  #
  # step3 - 의류 폼 초기화
  #
  $('#btn-cloth-reset').click ->
    $('#cloth-type').select2('val', '')
    clear_cloth_form true

  #
  # step3 - 의류 추가
  #
  $('#btn-cloth-add').click ->
    data =
      cloth_type:      $('#cloth-type').val(),
      cloth_type_str:  $('#cloth-type option:selected').text(),
      cloth_color:     $('#cloth-color').val(),
      cloth_color_str: $('#cloth-color option:selected').text(),
      cloth_bust:      $('#cloth-bust').val(),
      cloth_waist:     $('#cloth-waist').val(),
      cloth_hip:       $('#cloth-hip').val(),
      cloth_arm:       $('#cloth-arm').val(),
      cloth_length:    $('#cloth-length').val(),
      cloth_foot:      $('#cloth-foot').val(),

    return unless data.cloth_type

    #
    # 입력한 의류 정보 검증
    #
    count = 0
    valid_count = 0
    if $('#cloth-color').val()
      count++
      valid_count++
    else
      count++
    $('#step3 input:enabled').each (i, el) ->
      return unless /^cloth-/.test( $(el).attr('id') )
      count++
      valid_count++ if $(el).val() > 0
    return unless count == valid_count

    compiled = _.template($('#tpl-new-cloth-cloth-item').html())
    html = $(compiled(data))
    $('#display-cloth-list').append(html)

    $('#btn-cloth-reset').click()
    $('#cloth-type').focus()

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

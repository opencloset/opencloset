$ ->
  ## Global variable
  userID  = undefined
  donorID = ''

  #
  # step1 - 기증자 검색과 기증자 선택을 연동합니다.
  #
  add_registered_donor = ->
    query = $('#donor-search').val()

    return unless query

    $.ajax "/new-cloth.json",    # `/new-cloth` 로 donor 를 가져오는게 구림
      type: 'GET'
      data: { q: query }
      success: (donors, textStatus, jqXHR) ->
        compiled = _.template($('#tpl-new-cloth-donor-id').html())
        _.each donors, (donor) ->
          unless $("#donor-search-list input[data-donor-id='#{donor.id}']").length
            $html = $(compiled(donor))
            $html.find('input').attr('data-json', JSON.stringify(donor))
            $("#donor-search-list").prepend($html)
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->

  $('#donor-search').keypress (e) -> add_registered_donor() if e.keyCode is 13
  $('#btn-donor-search').click -> add_registered_donor()

  $('#donor-search-list').on 'click', ':radio', (e) ->
    userID  = $(@).data('user-id')
    donorID = $(@).data('donor-id')
    return if $(@).val() is '0'
    g = JSON.parse($(@).attr('data-json'))
    _.each ['name','email','gender','phone','age',
            'address','donation_msg','comment'], (name) ->
      $input = $("input[name=#{name}]")
      if $input.attr('type') is 'radio' or $input.attr('type') is 'checkbox'
        $input.each (i, el) ->
          $(el).attr('checked', true) if $(el).val() is g[name]
      else
        $input.val(g[name])

  #
  # step3 - 의류 종류 선택 콤보박스
  #
  clear_cloth_form = (show) ->
    if show
      _.each ['bust','waist','hip','arm','length','foot'], (name) ->
        $("#display-cloth-#{name}").show()
    else
      _.each ['bust','waist','hip','arm','length','foot'], (name) ->
        $("#display-cloth-#{name}").hide()

    $('#cloth-color').select2('val', '')
    _.each ['bust','waist','hip','arm','length','foot'], (name) ->
      $("#cloth-#{name}").prop('disabled', true).val('')

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
      cloth_gender:    $('input[name=designated-for]:checked').val()

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

      ajax = {}
      switch info.step
        when 2
          return unless $('#donor-name').val()

          ajax.type = 'POST'
          ajax.path = '/users.json'

          if userID
            ajax.type = 'PUT'
            ajax.path = "/users/#{userID}.json"

          $.ajax ajax.path,
            type: ajax.type
            data: $('form').serialize()
            success: (data, textStatus, jqXHR) ->
              userID = data.id
              if donorID
                ajax.type = 'PUT'
                ajax.path = "/donors/#{donorID}.json"
              else
                ajax.type = 'POST'
                ajax.path = "/donors.json?user_id=#{userID}"

              $.ajax ajax.path,
                type: ajax.type
                data: $('form').serialize()
                success: (data, textStatus, jqXHR) ->
                  donorID = data.id
                  return true
                error: (jqXHR, textStatus, errorThrown) ->
                  alert('error', jqXHR.responseJSON.error)
                  return false
                complete: (jqXHR, textStatus) ->
            error: (jqXHR, textStatus, errorThrown) ->
              alert('error', jqXHR.responseJSON.error)
              return false
            complete: (jqXHR, textStatus) ->
        when 3
          return unless $("input[name=cloth-list]:checked").length
          $.ajax '/clothes.json',
            type: 'POST'
            data: "#{$('form').serialize()}&donor_id=#{donorID}"
            success: (data, textStatus, jqXHR) ->
              return true
            error: (jqXHR, textStatus, errorThrown) ->
              alert('error', jqXHR.responseJSON.error)
              return false
            complete: (jqXHR, textStatus) ->
        else return

    .on 'finished', (e) ->
      location.href = "/"
      false
    .on 'stepclick', (e) ->
      # false

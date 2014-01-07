$ ->
  ## Global variable
  userID  = undefined

  #
  # step1 - 기증자 검색과 기증자 선택을 연동합니다.
  #
  addRegisteredUser = ->
    query = $('#user-search').val()

    return unless query

    $.ajax "/api/search/user.json",
      type: 'GET'
      data: { q: query }
      success: (data, textStatus, jqXHR) ->
        compiled = _.template($('#tpl-user-id').html())
        _.each data, (user) ->
          unless $("#user-search-list input[data-user-id='#{user.id}']").length
            $html = $(compiled(user))
            $html.find('input').attr('data-json', JSON.stringify(user))
            $("#user-search-list").prepend($html)
      error: (jqXHR, textStatus, errorThrown) ->
        type = jqXHR.status is 404 ? 'warning' : 'danger'
        alert(type, jqXHR.responseJSON.error.str)
      complete: (jqXHR, textStatus) ->

  $('#user-search-list').on 'click', ':radio', (e) ->
    userID = $(@).data('user-id')
    return if $(@).val() is '0'
    g = JSON.parse($(@).attr('data-json'))
    _.each [
      'name',
      'email',
      'phone',
      'address',
      'gender',
      'birth',
    ], (name) ->
      $input = $("input[name=#{name}]")
      if $input.attr('type') is 'radio' or $input.attr('type') is 'checkbox'
        $input.each (i, el) ->
          $(el).attr('checked', true) if $(el).val() is g[name]
      else
        $input.val(g[name])

  $('#user-search').keypress (e) -> addRegisteredUser() if e.keyCode is 13
  $('#btn-user-search').click -> addRegisteredUser()
  addRegisteredUser()

  #
  # step3 - 의류 종류 선택 콤보박스
  #
  clear_clothes_form = (show) ->
    if show
      _.each ['bust','waist','hip','arm','length','foot'], (name) ->
        $("#display-clothes-#{name}").show()
    else
      _.each ['bust','waist','hip','arm','length','foot'], (name) ->
        $("#display-clothes-#{name}").hide()

    $('input[name=clothes-gender]').prop('checked', false)
    $('#clothes-color').select2('val', '')
    _.each ['bust','waist','hip','arm','length','foot'], (name) ->
      $("#clothes-#{name}").prop('disabled', true).val('')

  $('#clothes-type').select2( dropdownCssClass: 'bigdrop' )
    .on 'change', (e) ->
      clear_clothes_form false
      types = []
      #
      # check Opencloset::Constant
      #
      switch parseInt( e.val, 10 )
        when 0x0001 | 0x0002                then types = [ 'bust', 'arm', 'waist', 'length'        ] # Jacket & Pants
        when 0x0001 | 0x0020                then types = [ 'bust', 'arm', 'waist', 'hip', 'length' ] # Jacket & Skirts
        when 0x0001, 0x0004, 0x0080, 0x0400 then types = [ 'bust', 'arm'                           ] # Jacket, Shirts, Coat, Blouse
        when 0x0002                         then types = [ 'waist', 'length'                       ] # Pants
        when 0x0200                         then types = [ 'waist', 'hip', 'length'                ] # Skirt
        when 0x0008                         then types = [ 'foot'                                  ] # Shoes
        when 0x0040                         then types = [ 'waist'                                 ] # Waistcoat
        when 0x0010, 0x0020, 0x0100         then types = [                                         ] # Hat, Tie, Onepiece
        else                                     types = [                                         ]
      for type in types
        $("#display-clothes-#{type}").show()
        $("#clothes-#{type}").prop('disabled', false)
  $('#clothes-color').select2()

  $('#clothes-type').select2('val', '')
  clear_clothes_form true

  #
  # step3 - 의류 폼 초기화
  #
  $('#btn-clothes-reset').click ->
    $('#clothes-type').select2('val', '')
    clear_clothes_form true

  #
  # step3 - 의류 추가
  #
  $('#btn-clothes-add').click ->
    data =
      user_id:            userID,
      clothes_type:       $('#clothes-type').val(),
      clothes_type_str:   $('#clothes-type option:selected').text(),
      clothes_gender:     $('input[name=clothes-gender]:checked').val()
      clothes_gender_str: $('input[name=clothes-gender]:checked').next().text()
      clothes_color:      $('#clothes-color').val(),
      clothes_color_str:  $('#clothes-color option:selected').text(),
      clothes_bust:       $('#clothes-bust').val(),
      clothes_waist:      $('#clothes-waist').val(),
      clothes_hip:        $('#clothes-hip').val(),
      clothes_arm:        $('#clothes-arm').val(),
      clothes_length:     $('#clothes-length').val(),
      clothes_foot:       $('#clothes-foot').val(),

    return unless data.clothes_type

    #
    # 입력한 의류 정보 검증
    #
    count = 0
    valid_count = 0
    if $('#clothes-color').val()
      count++
      valid_count++
    else
      count++
    $('#step3 input:enabled').each (i, el) ->
      return unless /^clothes-/.test( $(el).attr('id') )
      count++
      valid_count++ if $(el).val() > 0
    return unless count == valid_count

    compiled = _.template($('#tpl-clothes-item').html())
    html = $(compiled(data))
    $('#display-clothes-list').append(html)

    $('#btn-clothes-reset').click()
    $('#clothes-type').focus()

  #
  # step3 - 추가한 모든 의류 선택 또는 해제
  #
  $('#btn-clothes-select-all').click ->
    count   = 0
    checked = 0
    $('input[name=clothes-list]').each (i, el) ->
      count++
      checked++ if $(el).prop('checked')
    $('input[name=clothes-list]').prop( 'checked', ( checked < count ? true : false ) )

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
              if userID
                ajax.type = 'PUT'
                ajax.path = "/donors/#{userID}.json"
              else
                ajax.type = 'POST'
                ajax.path = "/donors.json?user_id=#{userID}"

              $.ajax ajax.path,
                type: ajax.type
                data: $('form').serialize()
                success: (data, textStatus, jqXHR) ->
                  userID = data.id
                  return true
                error: (jqXHR, textStatus, errorThrown) ->
                  alert('danger', jqXHR.responseJSON.error)
                  return false
                complete: (jqXHR, textStatus) ->
            error: (jqXHR, textStatus, errorThrown) ->
              alert('danger', jqXHR.responseJSON.error)
              return false
            complete: (jqXHR, textStatus) ->
        when 3
          return unless $("input[name=clothes-list]:checked").length
          $.ajax '/clothes.json',
            type: 'POST'
            data: $('form').serialize()
            success: (data, textStatus, jqXHR) ->
              return true
            error: (jqXHR, textStatus, errorThrown) ->
              alert('danger', jqXHR.responseJSON.error)
              return false
            complete: (jqXHR, textStatus) ->
        else return

    .on 'finished', (e) ->
      location.href = "/"
      false
    .on 'stepclick', (e) ->
      # false

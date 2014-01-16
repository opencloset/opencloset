$ ->
  ## Global variable
  userID  = undefined

  ## main
  $('#input-phone').ForceNumericOnly()

  #
  # step1 - 대여자 검색과 대여자 선택을 연동합니다.
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
        $("input[name=user-id][value=#{ data[0].id }]").click() if data[0]
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
      'height',
      'weight',
      'bust',
      'waist',
      'hip',
      'belly',
      'thigh',
      'arm',
      'leg',
      'knee',
      'foot',
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
  #
  #

  $('#input-target-date').datepicker
    startDate: "-0d"
    language: 'kr'
    format: 'yyyy-mm-dd'
    autoclose: true

  $('#btn-sendsms:not(.disabled)').click (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')
    to = $('#input-phone').val()
    return unless to
    $.ajax "/sms.json",
      type: 'POST'
      data: { to: to }
      success: (data, textStatus, jqXHR) ->
        alert('success', "#{to} 번호로 SMS 가 발송되었습니다")
      error: (jqXHR, textStatus, errorThrown) ->
        alert('danger', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')

  validation = false
  $('#fuelux-wizard').ace_wizard()
    .on 'change', (e, info) ->
      if info.step is 1 && validation
        return false unless $('#validation-form').valid()

      # "다음"으로 움직일 때만 Ajax 호출을 수행하고
      # "이전"으로 움직일 때는 아무 동작도 수행하지 않습니다.
      return true unless info.direction is 'next'

      ajax = {}
      switch info.step
        when 2
          if userID
            ajax.type = 'PUT'
            ajax.path = "/api/user/#{userID}.json"
          else
            ajax.type = 'POST'
            ajax.path = '/api/user.json'

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
        when 3
          if userID
            ajax.type = 'PUT'
            ajax.path = "/api/user/#{userID}.json"
          else
            ajax.type = 'POST'
            ajax.path = '/api/user.json'

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
        else return
        
    .on 'finished', (e) ->
      e.preventDefault()
      bust  = $("input[name=bust]").val()
      waist = $("input[name=waist]").val()
      location.href = "/search?q=#{parseInt(bust) + 3}/#{waist}//1/&gid=#{userID}"
      false
    .on 'stepclick', (e) ->

  why = $('#user-why').tag({
    placeholder: $('#user-why').attr('placeholder'),
    source: [
      '입사면접',
      '사진촬영',
      '결혼식',
      '장례식',
      '입학식',
      '졸업식',
      '세미나',
      '발표',
    ],
  })
  $('.user-why .clickable.label').click ->
    text = $(@).text()
    e = $.Event('keydown', { keyCode: 13 })
    $('input#purpose').next().val(text).trigger(e)

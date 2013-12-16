$ ->
  ## Global variable
  userID  = undefined
  guestID = undefined

  ## main
  $('#input-phone').ForceNumericOnly()

  #
  # step1 - 대여자 검색과 대여자 선택을 연동합니다.
  #
  add_registered_user = ->
    query = $('#user-search').val()

    return unless query

    $.ajax "/api/search/user.json",
      type: 'GET'
      data: { q: query }
      success: (data, textStatus, jqXHR) ->
        compiled = _.template($('#tpl-new-borrower-user-id').html())
        _.each data, (user) ->
          unless $("#user-search-list input[data-user-id='#{user.id}']").length
            $html = $(compiled(user))
            $html.find('input').attr('data-json', JSON.stringify(user))
            $("#user-search-list").prepend($html)
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->

  $('#user-search-list').on 'click', ':radio', (e) ->
    userID  = $(@).data('user-id')
    guestID = $(@).data('guest-id')
    return if $(@).val() is '0'
    g = JSON.parse($(@).attr('data-json'))
    _.each ['name','email','gender','phone','birth',
            'address','height','weight','purpose',
            'bust','waist','arm','length','domain'], (name) ->
      $input = $("input[name=#{name}]")
      if $input.attr('type') is 'radio' or $input.attr('type') is 'checkbox'
        $input.each (i, el) ->
          $(el).attr('checked', true) if $(el).val() is g[name]
      else
        $input.val(g[name])

  $('#user-search').keypress (e) -> add_registered_user() if e.keyCode is 13
  $('#btn-user-search').click -> add_registered_user()

  #
  #
  #

  $('.clickable.label').click ->
    $('#input-purpose').val($(@).text())

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
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')

  validation = false
  $('#fuelux-wizard').ace_wizard()
    .on 'change', (e, info) ->
      if info.step is 1 && validation
        return false unless $('#validation-form').valid()

      ajax = {}
      switch info.step
        when 2
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
              return true
            error: (jqXHR, textStatus, errorThrown) ->
              alert('error', jqXHR.responseJSON.error)
              return false
            complete: (jqXHR, textStatus) ->
        when 4
          if guestID
            ajax.type = 'PUT'
            ajax.path = "/guests/#{guestID}.json"
          else
            ajax.type = 'POST'
            ajax.path = "/guests.json?user_id=#{userID}"

          $.ajax ajax.path,
            type: ajax.type
            data: $('form').serialize()
            success: (data, textStatus, jqXHR) ->
              userID  = data.user_id
              guestID = data.id
              return true
            error: (jqXHR, textStatus, errorThrown) ->
              alert('error', jqXHR.responseJSON.error)
              return false
            complete: (jqXHR, textStatus) ->
        else return
        
    .on 'finished', (e) ->
      e.preventDefault()
      bust  = $("input[name=bust]").val()
      waist = $("input[name=waist]").val()
      location.href = "/search?q=#{parseInt(bust) + 3}/#{waist}//1/&gid=#{guestID}"
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

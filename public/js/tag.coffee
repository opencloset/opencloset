$ ->
  $('#query').focus()
  $('#btn-tag-add').click (e) ->
    $('#add-form').trigger('submit')

  $('#add-form').submit (e) ->
    e.preventDefault()
    query = $('#query').val()
    $('#query').val('').focus()
    return unless query

  #
  # inline editable field
  #
  $('.editable').each (i, el) ->
    params =
      mode:        'inline'
      showbuttons: 'true'
      emptytext:   '비어있음'
      url: (params) ->
        return alert('danger', '변경할 태그 이름을 입력하세요.') unless params.value

        base_url = $('#tag-data').data('base-url')
        data = {}
        data[params.name] = params.value
        $.ajax "#{ base_url }/#{ params.pk }.json",
          type: 'PUT'
          data: data
      error: (response, newValue) ->
        msg = response.responseJSON.error.str
        switch response.status
          when 404 then msg = "#{params.value} 태그를 찾을 수 없습니다."
          when 500
            if msg is 'duplicate tag.name'
              msg = "#{newValue} 태그가 이미 존재합니다."
        return msg

    id = $(el).attr('id')
    if 0
    else
      params.type = 'text'

    $(el).editable params

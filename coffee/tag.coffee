$ ->
  #
  # 태그 더하기
  #
  $('#query').focus()
  $('#btn-tag-add').click (e) ->
    $('#add-form').trigger('submit')

  $('#add-form').submit (e) ->
    e.preventDefault()
    query = $('#query').val()
    $('#query').val('').focus()
    return unless query

    base_url = $('#tag-data').data('base-url')
    $.ajax "#{ base_url }.json",
      type: 'POST'
      data: { name: query, label: query }
      success: (data, textStatus, jqXHR) ->
        compiled = _.template($('#tpl-tag').html())
        html = $(compiled(data))
        $("#tag-table table tbody").append(html)

        makeEditable "#tag-id-#{ data.id }"
      error: (jqXHR, textStatus, errorThrown) ->
        msg = jqXHR.responseJSON.error.str
        switch jqXHR.status
          when 400
            if msg is 'duplicate tag.name'
              msg = "\"#{query}\" 태그가 이미 존재합니다."
        OpenCloset.alert 'danger', msg

  #
  # 태그 지우기
  #
  $('.btn-tag-remove').click (e) ->
    tag_id = $(this).data('tag-id')
    return unless tag_id

    base_url = $('#tag-data').data('base-url')
    $.ajax "#{ base_url }/#{ tag_id }.json",
      type: 'DELETE'
      success: (data, textStatus, jqXHR) ->
        $(".tag-id-#{ data.id }").remove()
      error: (jqXHR, textStatus, errorThrown) ->
        msg = jqXHR.responseJSON.error.str
        switch jqXHR.status
          when 404 then msg = "\"#{query}\" 태그를 찾을 수 없습니다."
        OpenCloset.alert 'danger', msg

  #
  # inline editable field
  #
  makeEditable = (el) ->
    params =
      mode:        'inline'
      showbuttons: 'true'
      emptytext:   '비어있음'
      url: (params) ->
        if params.name is 'name'
          return OpenCloset.alert('danger', '변경할 태그 이름을 입력하세요.') unless params.value

        base_url = $('#tag-data').data('base-url')
        data = {}
        data[params.name] = params.value
        $.ajax "#{ base_url }/#{ params.pk }.json",
          type: 'PUT'
          data: data
      error: (response, newValue) ->
        msg = response.responseJSON.error.str
        switch response.status
          when 404 then msg = "\"#{params.value}\" 태그를 찾을 수 없습니다."
          when 400
            if msg is 'duplicate tag.name'
              msg = "\"#{newValue}\" 태그가 이미 존재합니다."
        return msg

    id = $(el).attr('id')
    if 0
    else
      params.type = 'text'

    $(el).editable params

  #
  # 태그 갱신
  #
  $('.editable').each (i, el) -> makeEditable el

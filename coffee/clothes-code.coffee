$ ->
  $('.order-status').each (i, el) ->
    $(el).addClass OpenCloset.status[ $(el).data('status') ].css
    $(el).find('.order-status-str').html('연장중') if $(el).data('status') is '대여중' and $(el).data('late-fee') > 0

  $('.clothes-code').each (i, el) ->
    $(el).html OpenCloset.trimClothesCode $(el).html()

  $(".chosen-select").chosen({ width: '90%' }).change ->
    tag_list     = $(this).val()
    clothes_code = $(this).data('clothes-code')
    base_url     = $(this).data('base-url')

    $.ajax "#{ base_url }/clothes/#{ clothes_code }/tag.json",
      type: 'PUT'
      data: $.param({ tag_id: tag_list }, 1)

  #
  # inline editable field
  #
  $('.editable').each (i, el) ->
    params =
      mode:        'inline'
      showbuttons: 'true'
      emptytext:   '비어있음'
      pk:          $('#profile-clothes-info-data').data('pk')
      url: (params) ->
        url = $('#profile-clothes-info-data').data('url')
        data = {}
        data[params.name] = params.value
        $.ajax url,
          type: 'PUT'
          data: data

    switch $(el).attr('id')
      when 'clothes-category'
        params.type    = 'select'
        params.source  = ( { value: k, text: v.str } for k, v of OpenCloset.category )
        params.display = (value) ->
          $(this).html OpenCloset.category[value].str
      when 'clothes-gender'
        params.type    = 'select'
        params.source  = [
          { value: 'male',   text: "남성용"   },
          { value: 'female', text: "여성용"   },
          { value: 'unisex', text: "남녀공용" },
        ]
        params.display = (value) ->
          switch value
            when 'male'   then value_str = '남성용'
            when 'female' then value_str = '여성용'
            when 'unisex' then value_str = '남녀공용'
            else               value_str = ''
          $(this).html value_str
      when 'clothes-color'
        params.type   = 'select'
        params.source = []
        params.source.push { value: color, text: color_str } for color, color_str of OpenCloset.color
      when 'clothes-comment'
        params.type = 'textarea'
      else
        params.type = 'text'

    $(el).editable params

  $('#form-suit').submit (e) ->
    e.preventDefault()
    action = $(@).attr('action')
    $.ajax action,
      type: 'POST'
      data: $(@).serialize()
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert 'error', textStatus
      complete: (jqXHR, textStatus) ->

  $('.clothes-group-item :checkbox').on 'click', (e) ->
    bool = $(@).prop 'checked'
    return unless bool

    code = $(@).next().text()
    $('#form-suit input[type=text]').val(code)
    $('#form-suit').trigger('submit')

  $('.btn-not-suit:not(.disabled)').on 'click', (e) ->
    e.preventDefault()

    return unless confirm "셋트 의류를 해체하시겠습니까?"

    $this = $(@)
    $this.addClass('disabled')
    href = $this.attr('href')
    $.ajax href,
      type: 'DELETE'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert 'error', textStatus
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')

  $('#btn-delete').click ->
    return unless confirm "의류가 삭제 될 것입니다. 동의하십니까?"
    $.ajax "/api#{location.pathname}",
      type: 'DELETE'
      success: (data, textStatus, jqXHR) ->
        location.href = '/clothes'
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->

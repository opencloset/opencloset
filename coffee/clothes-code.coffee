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
      when 'clothes-discard-to'
        params.type    = 'select'
        params.source  = [
          { value: '옷캔', text: '옷캔' },
          { value: '비백', text: '비백' },
          { value: '영구보관', text: '영구보관' },
          { value: '재활용불가', text: '재활용불가' }
        ]
        params.display = (value) ->
          $(this).html value
        params.url = (params) ->
          code = $(@).data('clothes-code')
          url = "/api/clothes/#{code}/discard"
          data = {}
          data[params.name] = params.value
          $.ajax url,
            type: 'PUT'
            data: data
      when 'clothes-discard-comment'
        params.type    = 'select'
        params.source  = [
          { value: '손상 수선 불가', text: '손상 수선 불가' },
          { value: '오염 제거 불가', text: '오염 제거 불가' },
          { value: '변색', text: '변색' },
          { value: '사용하지 않는 스타일', text: '사용하지 않는 스타일' },
          { value: '짝 잃음', text: '짝 잃음' }
        ]
        params.display = (value) ->
          $(this).html value
        params.url = (params) ->
          code = $(@).data('clothes-code')
          url = "/api/clothes/#{code}/discard"
          data = {}
          data[params.name] = params.value
          $.ajax url,
            type: 'PUT'
            data: data
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

  $dz  = $('#clothes-dropzone')
  code = $('#clothes-code.clothes-code').text()
  Dropzone.options.clothesDropzone =
    paramName: $dz.data('dz-name')
    maxFiles: 1
    init: ->
      mockFile = { name: 'photo', size: 12345 }
      @emit('addedfile', mockFile)
      @emit('thumbnail', mockFile, $dz.data('dz-thumbnail'))
      @emit('complete', mockFile)
      @on 'sending', (file, xhr, formData) ->
        formData.append('key', code)
      @on 'success', (file) ->
        @emit('removedfile', mockFile)

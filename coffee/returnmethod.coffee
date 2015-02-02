###
<a href="#" id="returnmethod" data-type="returnmethod" data-name="key">awesome</a>
<script>
  $('#returnmethod').editable
    source: ['Fedex', 'DHL']
    value:
      company: 'Fedex'
      trackingNumber: '123456'
</script>
###
ReturnMethod = (opts) ->
  @sourceData = opts.source
  @init('returnmethod', opts, ReturnMethod.defaults)
  
# inherit from Abstract input
$.fn.editableutils.inherit(ReturnMethod, $.fn.editabletypes.abstractinput)

$.extend ReturnMethod.prototype,
  render: ->
    @$input = @$tpl.find('input')
    @$list = @$tpl.find('select')
    @$list.empty()
    @$list.append($('<option>', {value: item}).text(item)) for item in @sourceData
  value2html: (value, element) ->
    return $(element).empty() unless value
    $(element).html [value.company, value.trackingNumber].join(',')
  html2value: (html) ->
    [company, trackingNumber] = html.split(',')
    return { company: company, trackingNumber: trackingNumber }
  value2str: (value) ->
    @$list = @$tpl.find('select')
    return [value.company, value.trackingNumber].join(',')
  str2value: (str) ->
    return str
  value2input: (value) ->
    return unless value
    @$list.val(value.company)
    @$input.filter('[name="trackingNumber"]').val(value.trackingNumber)
  input2value: ->
    company: @$list.val()
    trackingNumber: @$input.filter('[name="trackingNumber"]').val()
  activate: ->
    @$list.focus()
  autosubmit: ->
    @$input.keydown (e) ->
      if e.which is 13 then $(@).closest('form').submit()

ReturnMethod.defaults = $.extend {}, $.fn.editabletypes.abstractinput.defaults,
  tpl: '''
    <div class="editable-returnmethod">
      <label><select name="company"></select></label>
      <label><input type="text" name="trackingNumber" placeholder="운송장번호"></label>
    </div>
  '''
  inputclass: ''
  source: []

$.fn.editabletypes.returnmethod = ReturnMethod

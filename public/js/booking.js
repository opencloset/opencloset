$(function() {
  $("#query").datepicker({
    todayHighlight: true,
    autoclose: true
  }).on('changeDate', function(e) {
    var ymd;
    ymd = $('#query').prop('value');
    return window.location = "/booking/" + ymd;
  });
  $('#btn-slot-open').click(function(e) {
    var ymd;
    ymd = $('#btn-slot-open').data('date-ymd');
    return window.location = "/booking/" + ymd + "/open";
  });
  return $('.editable').each(function(i, el) {
    var params;
    params = {
      mode: 'inline',
      showbuttons: 'true',
      emptytext: '비어있음',
      url: function(params) {
        var data, url;
        url = $("#booking-data").data('url') + ("/" + params.pk + ".json");
        data = {};
        data[params.name] = params.value;
        return $.ajax(url, {
          type: 'PUT',
          data: data
        });
      }
    };
    params.type = 'text';
    return $(el).editable(params);
  });
});

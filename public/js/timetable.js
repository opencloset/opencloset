$(function() {
  var updateTimeTablePerson;
  $("#query").datepicker({
    todayHighlight: true,
    autoclose: true
  }).on('changeDate', function(e) {
    var ymd;
    ymd = $('#query').prop('value');
    return window.location = "/timetable/" + ymd;
  });
  $('#btn-slot-open').click(function(e) {
    var ymd;
    ymd = $('#btn-slot-open').data('date-ymd');
    return window.location = "/timetable/" + ymd + "/open";
  });
  updateTimeTablePerson = function(btn) {
    var ub_id, ub_status, url;
    ub_id = $(btn).data('id');
    ub_status = $(btn).data('status');
    url = $("#timetable-data").data('url') + ("/" + ub_id);
    $(btn).removeClass('btn-primary').removeClass('btn-danger').removeClass('btn-warning').removeClass('btn-success').removeClass('btn-info').removeClass('btn-inverse');
    if (ub_status === 'visiting') {
      return $(btn).addClass('btn-info');
    }
  };
  $('.btn.timetable-person').each(function(i, el) {
    return updateTimeTablePerson(el);
  });
  return $('.btn.timetable-person').click(function(e) {
    var btn, ub_id, ub_status, ub_status_new, url;
    btn = this;
    ub_id = $(btn).data('id');
    ub_status = $(btn).data('status');
    url = $("#timetable-data").data('url') + ("/" + ub_id + ".json");
    ub_status_new = '';
    if (ub_status === 'visiting') {
      ub_status_new = '';
    } else {
      ub_status_new = 'visiting';
    }
    $(btn).data('status', ub_status_new);
    return $.ajax(url, {
      type: 'PUT',
      data: {
        id: ub_id,
        status: ub_status_new,
        success: function(data, textStatus, jqXHR) {
          return updateTimeTablePerson(btn);
        }
      }
    });
  });
});

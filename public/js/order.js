$(function() {
  return $('span.order-status.label').each(function(i, el) {
    var status;
    status = $(el).data('order-status');
    if (status) {
      return $(el).addClass(OpenCloset.status[status].css);
    }
  });
});

// Generated by CoffeeScript 1.6.3
(function() {
  $(function() {
    return $('.order-status').each(function(i, el) {
      $(el).addClass(OpenCloset.getStatusCss($(el).data('status')));
      if ($(el).data('late-fee') > 0) {
        return $(el).find('.order-status-str').html('연체중');
      }
    });
  });

}).call(this);

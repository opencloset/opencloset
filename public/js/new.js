// Generated by CoffeeScript 1.6.3
(function() {
  $(function() {
    $('#input-phone').ForceNumericOnly();
    return $('.clickable.label').click(function() {
      return $('#input-purpose').val($(this).text());
    });
  });

}).call(this);

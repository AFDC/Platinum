// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require_tree .

$(function(){
    // Login Modal
    $("#loginModal").modal({
        "keyboard": true,
        "show": false
    });

    $("#navBar").delegate("#loginLink", "click", function() {
        $("#loginModal").modal("show");
        return false;
    });

    // Global Tooltips
    $(".hasTooltip").tooltip();

    // Global Popover
    $(".hasPopover").popover();

    // Global Dropdown
    $(".dropdown-toggle").dropdown();

    // Global timepicker
    $(".global-timepicker").parent().datetimepicker({
        pickDate: false,
        pick12HourFormat: true,
        pickSeconds: false
    });

    // Global datepicker
    $(".global-datepicker").parent().datetimepicker({
        pickTime: false
    });

    $("div.uneditable-input").each(function(){
        if ($(this).data('value')) {
            $(this).text($(this).data('value'));
        }
    });


    $(document).on('change', '.btn-file :file', function() {
        var input = $(this),
            numFiles = input.get(0).files ? input.get(0).files.length : 1,
            label = input.val().replace(/\\/g, '/').replace(/.*\//, '');
        input.trigger('fileselect', [numFiles, label]);
    });

    $('.btn-file :file').on('fileselect', function(event, numFiles, label) {
        var display_input = $(this).parent().parent().children('input:text');
        if (display_input) {
            display_input.val(label);
        }
    });

    $(".confirm").submit(function(e) {
        if (!confirm("Are you sure? This cannot be undone.")) {
            e.preventDefault();
        }
    });

    $(".countdown").each(function(i, el){
        if (this.getAttribute("data-expiration")) {
            var expiredMessage = this.getAttribute("data-expire-message");
            var expirationDate = el.getAttribute("data-expiration");
            var updateExpiration = function() {
                var cd = countdown(expirationDate * 1000);

                var msg = cd.toString();

                if (cd.minutes < 3) {
                    msg = "<b>" + msg + "</b>";
                }

                if (cd.value >= 0) {
                    msg = "<b>" + expiredMessage + "</b>";
                    clearInterval(myInverval);
                }

                el.innerHTML = msg;
            };

            updateExpiration();

            var myInverval = setInterval(updateExpiration, 1000);
        }
    });
});


// window.smartlook||(function(d) {
//     var o=smartlook=function(){ o.api.push(arguments)},h=d.getElementsByTagName('head')[0];
//     var c=d.createElement('script');o.api=new Array();c.async=true;c.type='text/javascript';
//     c.charset='utf-8';c.src='https://web-sdk.smartlook.com/recorder.js';h.appendChild(c);
//     })(document);
//     smartlook('init', 'f88634ea700a2855d240f06e31b8ead7e366db45', { region: 'eu' });

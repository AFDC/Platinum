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
});

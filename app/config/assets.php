<?php

return array(
    /*
     * Javascript on footer
     */
    array(
        /* this means all pages */
        'request_match' => array('*'),
        'css' => array(
            /* MAIN CSS (REQUIRED ALL PAGE) */
            '/assets/css/bootstrap.min.css',
            '/assets/plugins/font-awesome/css/font-awesome.min.css',
            '/assets/css/style.css',
            '/assets/css/style-responsive.css',
            '/assets/css/sections/common.css',
            /* PLUGINS CSS */
            '/assets/plugins/weather-icon/css/weather-icons.min.css',
            '/assets/plugins/prettify/prettify.min.css',
            '/assets/plugins/magnific-popup/magnific-popup.min.css',
            '/assets/plugins/owl-carousel/owl.carousel.min.css',
            '/assets/plugins/owl-carousel/owl.theme.min.css',
            '/assets/plugins/owl-carousel/owl.transitions.min.css',
            '/assets/plugins/chosen/chosen.min.css',
            '/assets/plugins/icheck/skins/all.css',
            '/assets/plugins/datepicker/datepicker.min.css',
            '/assets/plugins/timepicker/bootstrap-timepicker.min.css',
            '/assets/plugins/validator/bootstrapValidator.min.css',
            '/assets/plugins/summernote/summernote.min.css',
            '/assets/plugins/markdown/bootstrap-markdown.min.css',
            '/assets/plugins/datatable/css/bootstrap.datatable.min.css'
        ),
        'js' => array(
            /* Main */
            '/assets/js/jquery.min.js',
            '/assets/js/bootstrap.min.js',
            '/assets/js/bootstrap-multiselect.js',
            '/assets/plugins/retina/retina.min.js',
            '/assets/plugins/nicescroll/jquery.nicescroll.js',
            '/assets/plugins/slimscroll/jquery.slimscroll.min.js',
            '/assets/plugins/backstretch/jquery.backstretch.min.js',
            /* PLUGINS */
            '/assets/plugins/jquery-forms/jquery.form.js',
            '/assets/plugins/skycons/skycons.js',
            '/assets/plugins/prettify/prettify.js',
            '/assets/plugins/magnific-popup/jquery.magnific-popup.min.js',
            '/assets/plugins/owl-carousel/owl.carousel.min.js',
            '/assets/plugins/chosen/chosen.jquery.min.js',
            '/assets/plugins/icheck/icheck.min.js',
            '/assets/plugins/datepicker/bootstrap-datepicker.js',
            '/assets/plugins/timepicker/bootstrap-timepicker.js',
            '/assets/plugins/mask/jquery.mask.min.js',
            '/assets/plugins/validator/bootstrapValidator.min.js',
            '/assets/plugins/datatable/js/jquery.dataTables.min.js',
            '/assets/plugins/datatable/js/bootstrap.datatable.js',
            '/assets/plugins/summernote/summernote.min.js',
            '/assets/plugins/markdown/markdown.js',
            '/assets/plugins/markdown/to-markdown.js',
            '/assets/plugins/markdown/bootstrap-markdown.js',
            '/assets/plugins/tmpl/tmpl.js',
            '/assets/plugins/makeusabrew/bootbox.min.js',
            /* KNOB JS */
            '/assets/plugins/jquery-knob/jquery.knob.js',
            '/assets/plugins/jquery-knob/knob.js',
            /* FLOT CHART JS */
            '/assets/plugins/flot-chart/jquery.flot.js',
            '/assets/plugins/flot-chart/jquery.flot.tooltip.js',
            '/assets/plugins/flot-chart/jquery.flot.resize.js',
            '/assets/plugins/flot-chart/jquery.flot.selection.js',
            '/assets/plugins/flot-chart/jquery.flot.stack.js',
            '/assets/plugins/flot-chart/jquery.flot.time.js',
            /* MORRIS JS */
            '/assets/plugins/morris-chart/raphael.min.js',
            '/assets/plugins/morris-chart/morris.min.js',
            /* C3 JS */
            '/assets/plugins/c3-chart/d3.v3.min.js',
            '/assets/plugins/c3-chart/c3.min.js',
            /* HIGHCHARTS */
            '/assets/plugins/highcharts/highcharts.js',
            /* MAIN APPS JS */
            '/assets/js/sections/common.js',
        ),
        'js-ifie' => array(
            '/assets/plugins/jquery-knob/excanvas.js',
            'https://oss.maxcdn.com/libs/html5shiv/3.7.0/html5shiv.js',
            'https://oss.maxcdn.com/libs/respond.js/1.4.2/respond.min.js'
        )
    ),
    array(
        /* pages starts with dashboard */
        'request_match' => array('dashboard*'),
        'css' => array(
            '/assets/css/bootstrap.min.css',
            '/assets/plugins/font-awesome/css/font-awesome.min.css',
            '/assets/css/style.css',
            '/assets/css/style-responsive.css',
            '/assets/css/sections/common.css',
        ),
        'js' => array(
            /* jquery upload */
            '/assets/plugins/jquery-ui/js/jquery-ui-1.10.4.min.js',
            '/assets/plugins/jquery-fileupload/jquery.fileupload.js'
        )
    )
,
    array(
        /* pages starts with admin/users */
        'request_match' => array('admin/users*'),
        'css' => array(
            '/assets/plugins/jquery-fileupload/jquery.fileupload.css',
            '/assets/plugins/jquery-fileupload/jquery.fileupload-ui.css',
        ),
        'js' => array(
            /* jquery upload */
            '/assets/plugins/jquery-ui/js/jquery-ui-1.10.4.min.js',
            '/assets/plugins/jquery-fileupload/jquery.fileupload.js'
        )
    )
,
    array(
        /* pages starts with admin/dashboard */
        'request_match' => array('admin/dashboard*'),
        'css' => array(
            '/assets/css/bootstrap.min.css',
            '/assets/plugins/font-awesome/css/font-awesome.min.css',
            '/assets/css/style.css',
            '/assets/css/style-responsive.css',
            '/assets/css/sections/common.css',
        ),
        'js' => array(
            /* jquery upload */
            '/assets/plugins/jquery-ui/js/jquery-ui-1.10.4.min.js',
            '/assets/plugins/jquery-fileupload/jquery.fileupload.js'
        )
    )
,
    array(
        /* pages starts with admin/users */
        'request_match' => array('admin/users*'),
        'css' => array(
            '/assets/css/bootstrap.min.css',
            '/assets/plugins/font-awesome/css/font-awesome.min.css',
            '/assets/css/style.css',
            '/assets/css/style-responsive.css',
            '/assets/css/sections/common.css',
        ),
        'js' => array(
            /* jquery upload */
            '/assets/plugins/jquery-ui/js/jquery-ui-1.10.4.min.js',
            '/assets/plugins/jquery-fileupload/jquery.fileupload.js'
        )
    )
,
    array(
        /* pages starts with admin/properties */
        'request_match' => array('admin/properties*'),
        'css' => array(
            '/assets/css/bootstrap.min.css',
            '/assets/plugins/font-awesome/css/font-awesome.min.css',
            '/assets/css/style.css',
            '/assets/css/style-responsive.css',
            '/assets/css/sections/common.css',
        ),
        'js' => array(
            /* jquery upload */
            '/assets/plugins/jquery-ui/js/jquery-ui-1.10.4.min.js',
            '/assets/plugins/jquery-fileupload/jquery.fileupload.js'
        )
    )
);

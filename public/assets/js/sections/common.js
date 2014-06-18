jQuery(document).ready(function() {
 	if (jQuery('.i-yellow-flat').length > 0){
		jQuery('input.i-yellow-flat').iCheck({
			checkboxClass: 'icheckbox_flat-yellow',
			radioClass: 'iradio_flat-yellow',
			increaseArea: '20%'
		});
	}
	 
	/** BEGIN MAGNIFIC POPUP **/
	if (jQuery('.magnific-popup-wrap').length > 0){
			jQuery('.magnific-popup-wrap').each(function() {
			"use strict";
				jQuery(this).magnificPopup({
					delegate: 'a.zooming',
					type: 'image',
					removalDelay: 300,
					mainClass: 'mfp-fade',
					gallery: {
					  enabled:true
					}
				});
			}); 
	}
	
	if (jQuery('.inline-popups').length > 0){
			jQuery('.inline-popups').magnificPopup({
			  delegate: 'a',
			  removalDelay: 500,
			  callbacks: {
				beforeOpen: function() {
				   this.st.mainClass = this.st.el.attr('data-effect');
				}
			  },
			  midClick: true
			});
	}
	/** END MAGNIFIC POPUP **/
    
    jQuery(document).bind('ajaxComplete',function(event,request,settings){
        if (request.getResponseHeader('Need-Auth')){
            window.location = '/';
        }
    });
});

/* User Dashboard only! */
$(document).ready(function(){

    $('.dashboard-charts .panel').each(function() {
	   initialiseDashboardLineChart($(this));
       initialiseDashboardLineChartFilters()
    });
        
    

});

function initialiseDashboardLineChartFilters()
{
    $('.chart-filter a').click(function(e){
        var chart = $(this).parents().eq(7);
        $(chart).find('li').removeClass('active');
        $(this).parent().addClass('active');
        $(chart).find('.panel-body div').css('opacity', 0.2);
        $(chart).css('cursor', 'wait');
        var filter = $(this).attr('data-filter');
        var template = $(chart).find('input[name="template"]').val();
        console.log($(chart).attr('id'));

        $.post( "/dashboard/refresh_chart", { template: template, filter: filter })
        .done(function( data ) {
            $(chart).html(data.chart);
            $(chart).css('cursor', '');
            $(chart).find('.panel-body div').css('opacity', 1);
            initialiseDashboardLineChart($(chart));
            initialiseDashboardLineChartFilters();
        }, "json");

        e.preventDefault();
    });
}
function initialiseDashboardLineChart(self)
{
    $(self).find('.panel-body').highcharts({
        title: {
            text: '',
            x: -20 //center
        },
        credits: {
          enabled: false
        },
        chart: {
            type: 'spline'
        },
        subtitle: {
            text: '',
        },
        xAxis: {
            categories: [1,2,3,4,5,6,7],
            
        },
        yAxis: {
            title: {
                text: ''
            },
            max: $(self).find('input[name="max"]').val(),
            min: 0,

            plotLines: [{
                value: 0,
                width: 1,
                color: '#808080'
            }]
        },
        tooltip: {
            valueSuffix: '',
            formatter: function() {
                // If you want to see what is available in the formatter, you can
                // examine the `this` variable.
                //     
                if($(self).find('input[name="'+ this.point.series['name'] + '-'+ this.point.category +'"]').length > 0)
                {
                    return $(self).find('input[name="'+ this.point.series['name'] + '-'+ this.point.category +'"]').val();
                }
                else
                {
                    return '<b>' + this.point.series['name'] + '</b>: ' + this.point.y;
                }
            }
        },
        legend: {
            padding: -5
        },
        series: [{
            name: 'High',
            data: JSON.parse($(self).find('input[name="high"]').val()),
                marker: {
                   enabled: false
                },
            color: '#CC333F'
        }, {
            name: 'Average',
            data: JSON.parse($(self).find('input[name="average"]').val()),
                marker: {
                   enabled: false
                },
            color: '#00A0B0'
        }, {
            name: 'Low',
            data: JSON.parse($(self).find('input[name="low"]').val()),
                marker: {
                   enabled: false
                },
            color: '#EDC951'
        }]
    });
}
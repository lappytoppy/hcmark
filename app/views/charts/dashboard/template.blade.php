@if(!isset($child))<div id="chart_{{ $template }}" class="chart-container">@endif
<div class="col-sm-4">
	<div class="panel panel-danger">
	  <div class="panel-heading">
		<ul class="nav navbar-nav pull-right toolbox">	
			<li><button type="button" class="btn btn-danger"><i class="glyphicon glyphicon-stats"></i></button></li>
			<li class="dropdown">
			<button type="button" class="btn btn-danger dropdown-toggle" data-toggle="dropdown"><i class="glyphicon glyphicon-cog"></i></button>
				<ul class="dropdown-menu danger square margin-list-rounded with-triangle chart-filter">
					<li @if($filter=="")class="active"@endif><a href="#" data-filter="">{{ Lang::get('ui.all_properties') }}</a></li>
					<li @if($filter=="all_hotels")class="active"@endif><a href="#" data-filter="all_hotels">{{ Lang::get('ui.all_hotels') }}</a></li>
					<li @if($filter=="all_apartments")class="active"@endif><a href="#" data-filter="all_apartments">{{ Lang::get('ui.all_apartments') }}</a></li>
					<li @if($filter=="5_star_hotels")class="active"@endif><a href="#" data-filter="5_star_hotels">{{ Lang::get('ui.n_star_hotels', array('n' => 5)) }}</a></li>
					<li @if($filter=="4_star_hotels")class="active"@endif><a href="#" data-filter="4_star_hotels">{{ Lang::get('ui.n_star_hotels', array('n' => 4)) }}</a></li>
					<li @if($filter=="3_star_hotels")class="active"@endif><a href="#" data-filter="3_star_hotels">{{ Lang::get('ui.n_star_hotels', array('n' => 3)) }}</a></li>
					<li @if($filter=="2_star_hotels")class="active"@endif><a href="#" data-filter="2_star_hotels">{{ Lang::get('ui.n_star_hotels', array('n' => 2)) }}</a></li>
					<li @if($filter=="1_star_hotels")class="active"@endif><a href="#" data-filter="1_star_hotels">{{ Lang::get('ui.n_star_hotels', array('n' => 1)) }}</a></li>
					<li @if($filter=="other_hotels")class="active"@endif><a href="#" data-filter="other_hotels">{{ Lang::get('ui.n_star_hotels', array('n' => 5)) }}</a></li>
				</ul>
			</li>
		</ul>
		<h3 class="panel-title">{{ Lang::get('headings.' . $template) }}</h3>
		
	  </div>
	  <div class="panel-footer">
		<span class="pull-right">
			@if($filter=="")
			{{ Lang::get('ui.all_properties') }}
			@endif
			@if($filter=="all_hotels")
			{{ Lang::get('ui.all_hotels') }}
			@endif
			@if($filter=="all_apartments")
			{{ Lang::get('ui.all_apartments') }}
			@endif
			@if($filter=="5_star_hotels")
			{{ Lang::get('ui.n_star_hotels', array('n' => 5)) }}
			@endif
			@if($filter=="4_star_hotels")
			{{ Lang::get('ui.n_star_hotels', array('n' => 4)) }}
			@endif
			@if($filter=="3_star_hotels")
			{{ Lang::get('ui.n_star_hotels', array('n' => 3)) }}
			@endif
			@if($filter=="2_star_hotels")
			{{ Lang::get('ui.n_star_hotels', array('n' => 2)) }}
			@endif
			@if($filter=="1_star_hotels")
			{{ Lang::get('ui.n_star_hotels', array('n' => 1)) }}
			@endif
			@if($filter=="other_hotels")
			{{ Lang::get('ui.other_hotels') }}
			@endif

		</span>
		<span>{{ Lang::get('ui.last_n_days', array('n' => count($processed_data))) }}</span>
	  </div><!-- /.panel-footer -->
	  	<input type="hidden" name="high" value="[{{ $serialised_data['high'] }}]" />
	  	<input type="hidden" name="low" value="[{{ $serialised_data['low'] }}]" />
	  	<input type="hidden" name="average" value="[{{ $serialised_data['average'] }}]" />
	  	@foreach($processed_data as $key=>$data)
	  	<input type="hidden" name="High-{{$key}}" value="<b>Top 3 High</b><br />{{$data['info']['high']}}" />
	  	<input type="hidden" name="Low-{{$key}}" value="<b>Top 3 Low</b><br />{{$data['info']['low']}}" />
	  	@endforeach
	  	<input type="hidden" name="template" value="{{ $template }}" />
	  	@if($template == 'occupancy' || $template == 'vacancy_rate')
	  	<input type="hidden" name="max" value="100" />
	  	@endif

	  <div class="panel-body">
		&nbsp;
	  </div><!-- /.panel-body -->
	</div><!-- /.panel panel-danger -->
</div><!-- /.col-sm-4 -->
@if(!isset($child))</div>@endif
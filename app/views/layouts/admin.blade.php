@include('layouts.include.head')
 
<body class="tooltips">
@include('layouts.include.system_messages')
<div class="wrapper">
	@include('layouts.include.top_nav')
	
	@include('layouts.include.left_sidebar')
	
	@include('layouts.include.right_heading')
	            
	@include('layouts.include.right_sidebar')
	            
	<div class="page-content">
		<div id="page-wrapper">
			@yield('content')
		</div>  
		@include('layouts.include.footer')
	</div>
</div>

@include('layouts.include.footer_scripts')

@yield('inline_scripts')

@include('layouts.include.body_close')
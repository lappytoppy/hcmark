<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
		<title>{{ $meta['title'] }} </title>
 
		<!-- BOOTSTRAP CSS (REQUIRED ALL PAGE)-->
		<link href="/assets/css/bootstrap.min.css" rel="stylesheet"> 
		
		<!-- MAIN CSS (REQUIRED ALL PAGE)-->
		<link href="/assets/plugins/font-awesome/css/font-awesome.min.css" rel="stylesheet">
		<link href="/assets/plugins/icheck/skins/flat/_all.css" rel="stylesheet">

		<link href="/assets/plugins/magnific-popup/magnific-popup.min.css" rel="stylesheet">
		<link href="/assets/css/style.css" rel="stylesheet">
		<link href="/assets/css/style-responsive.css" rel="stylesheet">
		<!-- HTML5 shim and Respond.js IE8 support of HTML5 elements and media queries -->
		<!--[if lt IE 9]>
		<script src="https://oss.maxcdn.com/libs/html5shiv/3.7.0/html5shiv.js"></script>
		<script src="https://oss.maxcdn.com/libs/respond.js/1.4.2/respond.min.js"></script>
		<![endif]-->
	</head>
 
	<body class="login tooltips">
	 	<!-- Start body content -->
	 	<div class="login-header text-center">
			<img src="/assets/img/logo-login.png" class="logo" alt="Logo">
		</div>
		<div id="page-wrapper">
			 @yield('content')
		</div>
		<!--  End body content -->
		
		
	
		<script src="/assets/js/jquery.min.js"></script>
		<script src="/assets/js/bootstrap.min.js"></script>
		<!-- PLUGINS -->
		<script src="/assets/plugins/magnific-popup/jquery.magnific-popup.min.js"></script>
		<script src="/assets/plugins/icheck/icheck.min.js"></script>
        <script src="/assets/plugins/nicescroll/jquery.nicescroll.js"></script> 

        <!-- including common JS for all pages -->
        <script src="/assets/js/sections/common.js"></script> 

	</body>
</html>
<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
		<title>{{ $meta['title'] }} </title>
 

		<!-- BOOTSTRAP CSS (REQUIRED ALL PAGE)-->
		<link href="/assets/css/bootstrap.min.css" rel="stylesheet">
		
		<!-- PLUGINS CSS -->
		<link href="/assets/plugins/weather-icon/css/weather-icons.min.css" rel="stylesheet">
		<link href="/assets/plugins/prettify/prettify.min.css" rel="stylesheet">
		<link href="/assets/plugins/magnific-popup/magnific-popup.min.css" rel="stylesheet">
		<link href="/assets/plugins/owl-carousel/owl.carousel.min.css" rel="stylesheet">
		<link href="/assets/plugins/owl-carousel/owl.theme.min.css" rel="stylesheet">
		<link href="/assets/plugins/owl-carousel/owl.transitions.min.css" rel="stylesheet">
		<link href="/assets/plugins/chosen/chosen.min.css" rel="stylesheet">
		<link href="/assets/plugins/icheck/skins/all.css" rel="stylesheet">
		<link href="/assets/plugins/datepicker/datepicker.min.css" rel="stylesheet">
		<link href="/assets/plugins/timepicker/bootstrap-timepicker.min.css" rel="stylesheet">
		<link href="/assets/plugins/validator/bootstrapValidator.min.css" rel="stylesheet">
		<link href="/assets/plugins/summernote/summernote.min.css" rel="stylesheet">
		<link href="/assets/plugins/markdown/bootstrap-markdown.min.css" rel="stylesheet">
		<link href="/assets/plugins/datatable/css/bootstrap.datatable.min.css" rel="stylesheet">
		<link href="/assets/plugins/morris-chart/morris.min.css" rel="stylesheet">
		<link href="/assets/plugins/c3-chart/c3.min.css" rel="stylesheet">
		<link href="/assets/plugins/slider/slider.min.css" rel="stylesheet">
		
		<!-- MAIN CSS (REQUIRED ALL PAGE)-->
		<link href="/assets/plugins/font-awesome/css/font-awesome.min.css" rel="stylesheet">
		<link href="/assets/css/style.css" rel="stylesheet">
		<link href="/assets/css/style-responsive.css" rel="stylesheet">
 	    <link href="/assets/css/sections/common.css" rel="stylesheet">
		<!-- HTML5 shim and Respond.js IE8 support of HTML5 elements and media queries -->
		<!--[if lt IE 9]>
		<script src="https://oss.maxcdn.com/libs/html5shiv/3.7.0/html5shiv.js"></script>
		<script src="https://oss.maxcdn.com/libs/respond.js/1.4.2/respond.min.js"></script>
		<![endif]-->
	</head>
 
	<body class="tooltips">
	
		
		
		
		<!--
		===========================================================
		BEGIN PAGE
		===========================================================
		-->
		<div class="wrapper">
			<!-- BEGIN TOP NAV -->
			<div class="top-navbar">
				<div class="top-navbar-inner">
					
					<!-- Begin Logo brand -->
					<div class="logo-brand">
						<a href="#fakelink"><img src="assets/img/sentir-logo-primary.png" alt="Logo"></a>
					</div><!-- /.logo-brand -->
					<!-- End Logo brand -->
					
					<div class="top-nav-content">
						
						<!-- Begin button sidebar left toggle -->
						<div class="btn-collapse-sidebar-left">
							<i class="fa fa-long-arrow-right icon-dinamic"></i>
						</div><!-- /.btn-collapse-sidebar-left -->
						<!-- End button sidebar left toggle -->
						 
						<!-- Begin button nav toggle -->
						<div class="btn-collapse-nav" data-toggle="collapse" data-target="#main-fixed-nav">
							<i class="fa fa-plus icon-plus"></i>
						</div><!-- /.btn-collapse-sidebar-right -->
						<!-- End button nav toggle -->
						
						
						<!-- Begin user session nav -->
						<ul class="nav-user navbar-right">
							<li class="dropdown">
							  <a href="#fakelink" class="dropdown-toggle" data-toggle="dropdown">
								<img src="assets/img/avatar/avatar.jpg" class="avatar img-circle" alt="Avatar">
								Hi, <strong>{{ ucfirst(Sentry::getUser()->full_name) }}</strong>
							  </a>
							  <ul class="dropdown-menu square primary margin-list-rounded with-triangle"> 
							  	<li><a href="/account">{{ Lang::get('nav.account') }}</a></li>
								<li><a href="/preferences">{{ Lang::get('nav.preferences') }}</a></li>
								<li class="divider"></li>
								<li><a href="/logout">{{ Lang::get('nav.logout') }}</a></li>
							  </ul>
							</li>
						</ul>
						<!-- End user session nav -->
						
						<!-- Begin Collapse menu nav -->
						<div class="collapse navbar-collapse" id="main-fixed-nav">
							<!-- Begin nav search form -->
							<form class="navbar-form navbar-left" role="search">
								<div class="form-group">
									<input type="text" class="form-control" placeholder="Search">
								</div>
							</form>
							<!-- End nav search form -->
							<ul class="nav navbar-nav navbar-left">
								<!-- Begin nav notification -->
								<li class="dropdown">
									<a href="#fakelink" class="dropdown-toggle" data-toggle="dropdown">
										<span class="badge badge-danger icon-count">7</span>
										<i class="fa fa-bell"></i>
									</a>
									<ul class="dropdown-menu square with-triangle">
										<li>
											<div class="nav-dropdown-heading">
											Notifications
											</div><!-- /.nav-dropdown-heading -->
											<div class="nav-dropdown-content scroll-nav-dropdown">
												<ul>
													<li class="unread"><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<strong>Thomas White</strong> posted on your profile page
														<span class="small-caps">17 seconds ago</span>
													</a></li>
													<li class="unread"><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<strong>Doina Slaivici</strong> uploaded photo
														<span class="small-caps">10 minutes ago</span>
													</a></li>
													<li><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<strong>Harry Nichols</strong> commented on your post
														<span class="small-caps">40 minutes ago</span>
													</a></li>
													<li class="unread"><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<strong>Mihaela Cihac</strong> send you a message
														<span class="small-caps">2 hours ago</span>
													</a></li>
													<li class="unread"><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<strong>Harold Chavez</strong> change his avatar
														<span class="small-caps">Yesterday</span>
													</a></li>
													<li class="unread"><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<strong>Elizabeth Owens</strong> posted on your profile page
														<span class="small-caps">Yesterday</span>
													</a></li>
													<li class="unread"><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<strong>Frank Oliver</strong> commented on your post
														<span class="small-caps">A week ago</span>
													</a></li>
													<li><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<strong>Mya Weastell</strong> send you a message
														<span class="small-caps">April 15, 2014</span>
													</a></li>
													<li><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<strong>Carl Rodriguez</strong> joined your weekend party
														<span class="small-caps">April 01, 2014</span>
													</a></li>
												</ul>
											</div><!-- /.nav-dropdown-content scroll-nav-dropdown -->
											<button class="btn btn-primary btn-square btn-block">See all notifications</button>
										</li>
									</ul>
								</li>
								<!-- End nav notification -->
								<!-- Begin nav task -->
								<li class="dropdown">
									<a href="#fakelink" class="dropdown-toggle" data-toggle="dropdown">
										<span class="badge badge-warning icon-count">3</span>
										<i class="fa fa-tasks"></i>
									</a>
									<ul class="dropdown-menu square margin-list-rounded with-triangle">
										<li>
											<div class="nav-dropdown-heading">
											Tasks
											</div><!-- /.nav-dropdown-heading -->
											<div class="nav-dropdown-content scroll-nav-dropdown">
												<ul>
													<li class="unread"><a href="#fakelink">
														<i class="fa fa-check-circle-o absolute-left-content icon-task completed"></i>
														Creating documentation
														<span class="small-caps">Completed : Yesterday</span>
													</a></li>
													<li><a href="#fakelink">
														<i class="fa fa-clock-o absolute-left-content icon-task progress"></i>
														Eating sands
														<span class="small-caps">Deadline : Tomorrow</span>
													</a></li>
													<li><a href="#fakelink">
														<i class="fa fa-clock-o absolute-left-content icon-task progress"></i>
														Sending payment
														<span class="small-caps">Deadline : Next week</span>
													</a></li>
													<li><a href="#fakelink">
														<i class="fa fa-exclamation-circle absolute-left-content icon-task uncompleted"></i>
														Uploading new version
														<span class="small-caps">Deadline: 2 seconds ago</span>
													</a></li>
													<li><a href="#fakelink">
														<i class="fa fa-exclamation-circle absolute-left-content icon-task uncompleted"></i>
														Drinking coffee
														<span class="small-caps">Deadline : 2 hours ago</span>
													</a></li>
													<li class="unread"><a href="#fakelink">
														<i class="fa fa-check-circle-o absolute-left-content icon-task completed"></i>
														Walking to nowhere
														<span class="small-caps">Completed : over a year ago</span>
													</a></li>
													<li class="unread"><a href="#fakelink">
														<i class="fa fa-check-circle-o absolute-left-content icon-task completed"></i>
														Sleeping under bridge
														<span class="small-caps">Completed : Dec 31, 2013</span>
													</a></li>
													<li class="unread"><a href="#fakelink">
														<i class="fa fa-check-circle-o absolute-left-content icon-task completed"></i>
														Buying some cigarettes
														<span class="small-caps">Completed : 2 days ago</span>
													</a></li>
												</ul>
											</div><!-- /.nav-dropdown-content scroll-nav-dropdown -->
											<button class="btn btn-primary btn-square btn-block">See all notifications</button>
										</li>
									</ul>
								</li>
								<!-- End nav task -->
								<!-- Begin nav message -->
								<li class="dropdown">
									<a href="#fakelink" class="dropdown-toggle" data-toggle="dropdown">
										<span class="badge badge-success icon-count">9</span>
										<i class="fa fa-envelope"></i>
									</a>
									<ul class="dropdown-menu square margin-list-rounded with-triangle">
										<li>
											<div class="nav-dropdown-heading">
											Messages
											</div><!-- /.nav-dropdown-heading -->
											<div class="nav-dropdown-content scroll-nav-dropdown">
												<ul>
													<li class="unread"><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														Lorem ipsum dolor sit amet, consectetuer adipiscing elit
														<span class="small-caps">17 seconds ago</span>
													</a></li>
													<li class="unread"><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														Duis autem vel eum iriure dolor in hendrerit in vulputate velit esse molestie consequat
														<span class="small-caps">10 minutes ago</span>
													</a></li>
													<li><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														I think so
														<span class="small-caps">40 minutes ago</span>
													</a></li>
													<li class="unread"><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														Yes, I'll be waiting
														<span class="small-caps">2 hours ago</span>
													</a></li>
													<li class="unread"><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														Thank you!
														<span class="small-caps">Yesterday</span>
													</a></li>
													<li class="unread"><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														No problem! I will never remember that
														<span class="small-caps">Yesterday</span>
													</a></li>
													<li class="unread"><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														Tak gepuk ndasmu sisan lho dab!
														<span class="small-caps">A week ago</span>
													</a></li>
													<li><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														Sorry bro, aku or atau sing jenenge ngono kui
														<span class="small-caps">April 15, 2014</span>
													</a></li>
													<li><a href="#fakelink">
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														Will you send me an invitation for your weeding party?
														<span class="small-caps">April 01, 2014</span>
													</a></li>
												</ul>
											</div><!-- /.nav-dropdown-content scroll-nav-dropdown -->
											<button class="btn btn-primary btn-square btn-block">See all message</button>
										</li>
									</ul>
								</li>
								<!-- End nav message -->
								<!-- Begin nav friend requuest -->
								<li class="dropdown">
									<a href="#fakelink" class="dropdown-toggle" data-toggle="dropdown">
										<span class="badge badge-info icon-count">2</span>
										<i class="fa fa-users"></i>
									</a>
									<ul class="dropdown-menu square margin-list-rounded with-triangle">
										<li>
											<div class="nav-dropdown-heading">
											Friend requests
											</div><!-- /.nav-dropdown-heading -->
											<div class="nav-dropdown-content static-list scroll-nav-dropdown">
												<ul>
													<li>
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<div class="row">
															<div class="col-xs-6">
																<strong>Craig Dixon</strong>
																<span class="small-caps">2 murtual friends</span>
															</div>
															<div class="col-xs-6 text-right btn-action">
																<button class="btn btn-success btn-xs">Accept</button><button class="btn btn-danger btn-xs">Ignore</button>
															</div><!-- /.col-xs-5 text-right btn-cation -->
														</div><!-- /.row -->
													</li>
													<li>
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<div class="row">
															<div class="col-xs-6">
																<strong>Mikayla King</strong>
																<span class="small-caps">20 murtual friends</span>
															</div>
															<div class="col-xs-6 text-right btn-action">
																<button class="btn btn-success btn-xs">Accept</button><button class="btn btn-danger btn-xs">Ignore</button>
															</div><!-- /.col-xs-5 text-right btn-cation -->
														</div><!-- /.row -->
													</li>
													<li>
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<div class="row">
															<div class="col-xs-6">
																<strong>Richard Dixon</strong>
																<span class="small-caps">1 murtual friend</span>
															</div>
															<div class="col-xs-6 text-right btn-action">
																<button class="btn btn-success btn-xs">Accept</button><button class="btn btn-danger btn-xs">Ignore</button>
															</div><!-- /.col-xs-5 text-right btn-cation -->
														</div><!-- /.row -->
													</li>
													<li>
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<div class="row">
															<div class="col-xs-6">
																<strong>Brenda Fuller</strong>
																<span class="small-caps">8 murtual friends</span>
															</div>
															<div class="col-xs-6 text-right btn-action">
																<button class="btn btn-success btn-xs">Accept</button><button class="btn btn-danger btn-xs">Ignore</button>
															</div><!-- /.col-xs-5 text-right btn-cation -->
														</div><!-- /.row -->
													</li>
													<li>
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<div class="row">
															<div class="col-xs-6">
																<strong>Ryan Ortega</strong>
																<span class="small-caps">122 murtual friends</span>
															</div>
															<div class="col-xs-6 text-right btn-action">
																<button class="btn btn-success btn-xs">Accept</button><button class="btn btn-danger btn-xs">Ignore</button>
															</div><!-- /.col-xs-5 text-right btn-cation -->
														</div><!-- /.row -->
													</li>
													<li>
														<img src="assets/img/avatar/avatar.jpg" class="absolute-left-content img-circle" alt="Avatar">
														<div class="row">
															<div class="col-xs-6">
																<strong>Jessica Gutierrez</strong>
																<span class="small-caps">45 murtual friends</span>
															</div>
															<div class="col-xs-6 text-right btn-action">
																<button class="btn btn-success btn-xs">Accept</button><button class="btn btn-danger btn-xs">Ignore</button>
															</div><!-- /.col-xs-5 text-right btn-cation -->
														</div><!-- /.row -->
													</li>
												</ul>
											</div><!-- /.nav-dropdown-content scroll-nav-dropdown -->
											<button class="btn btn-primary btn-square btn-block">See all request</button>
										</li>
									</ul>
								</li>
								<!-- End nav friend requuest -->
							</ul>
						</div><!-- /.navbar-collapse -->
						<!-- End Collapse menu nav -->
					</div><!-- /.top-nav-content -->
				</div><!-- /.top-navbar-inner -->
			</div><!-- /.top-navbar -->
			<!-- END TOP NAV -->
			
			
			
			<!-- BEGIN SIDEBAR LEFT -->
			<div class="sidebar-left sidebar-nicescroller">
				<ul class="sidebar-menu">
					<li><a href="#fakelink"><i class="fa fa-dashboard icon-sidebar"></i>Dashboard</a></li>
					<li class="active selected"><a href="#fakelink"><i class="fa fa-star icon-sidebar"></i>Active menu</a></li>
					<li>
						<a href="#fakelink">
							<i class="fa fa-desktop icon-sidebar"></i>
							<i class="fa fa-angle-right chevron-icon-sidebar"></i>
							Apps menu
							<span class="badge badge-warning span-sidebar">BADGE</span>
							</a>
						<ul class="submenu">
							<li><a href="#fakelink">Apps submenu<span class="label label-success span-sidebar">LABEL</span></a></li>
							<li><a href="#fakelink">Apps submenu</a></li>
							<li><a href="#fakelink">Apps submenu</a></li>
						</ul>
					</li>
					<li class="active selected">
						<a href="#fakelink">
							<i class="fa fa-cloud icon-sidebar"></i>
							<i class="fa fa-angle-right chevron-icon-sidebar"></i>
							Active and visible menu
							</a>
						<ul class="submenu visible">
							<li><a href="#fakelink">Apps submenu</a></li>
							<li class="active selected"><a href="#fakelink">Active submenu</a></li>
							<li><a href="#fakelink">Apps submenu</a></li>
						</ul>
					</li>
					
					
					<li class="static">MENU HEADING</li>
					<li><a href="#fakelink"><i class="fa fa-circle icon-sidebar"></i>Single menu</a></li>
					<li><a href="#fakelink"><i class="fa fa-circle-o icon-sidebar"></i>Single menu</a></li>
					
					
					<li class="static">AWESOME HEADING</li>
					<li class="text-content">
						<div class="switch">
							<div class="onoffswitch blank">
								<input type="checkbox" name="onoffswitch" class="onoffswitch-checkbox" id="onoffswitch1" checked>
								<label class="onoffswitch-label" for="onoffswitch1">
									<span class="onoffswitch-inner"></span>
									<span class="onoffswitch-switch"></span>
								</label>
							</div>
						</div>
						Example on off switch
					</li>
					<li class="text-content">
						<div class="switch">
							<div class="onoffswitch blank">
								<input type="checkbox" name="onoffswitch" class="onoffswitch-checkbox" id="onoffswitch2">
								<label class="onoffswitch-label" for="onoffswitch2">
									<span class="onoffswitch-inner"></span>
									<span class="onoffswitch-switch"></span>
								</label>
							</div>
						</div>
						Example on off switch
					</li>
					
				</ul>
			</div><!-- /.sidebar-left -->
			<!-- END SIDEBAR LEFT -->
			
			
			
			<!-- BEGIN SIDEBAR RIGHT HEADING -->
			<div class="sidebar-right-heading">
				<ul class="nav nav-tabs square nav-justified">
				  <li class="active"><a href="#online-user-sidebar" data-toggle="tab"><i class="fa fa-comments"></i></a></li>
				  <li><a href="#notification-sidebar" data-toggle="tab"><i class="fa fa-bell"></i></a></li>
				  <li><a href="#task-sidebar" data-toggle="tab"><i class="fa fa-tasks"></i></a></li>
				  <li><a href="#setting-sidebar" data-toggle="tab"><i class="fa fa-cogs"></i></a></li>
				</ul>
			</div><!-- /.sidebar-right-heading -->
			<!-- END SIDEBAR RIGHT HEADING -->
			
			
			
			<!-- BEGIN SIDEBAR RIGHT -->
			<div class="sidebar-right sidebar-nicescroller">
				<div class="tab-content">
				  <div class="tab-pane fade in active" id="online-user-sidebar">
					<ul class="sidebar-menu online-user">
						<li class="static">ONLINE USERS</li>
						<li><a href="#fakelink">
							<span class="user-status success"></span>
							<img src="assets/img/avatar/avatar.jpg" class="ava-sidebar img-circle" alt="Avatar">
							<i class="fa fa-mobile-phone device-status"></i>
							Thomas White 
							<span class="small-caps">Lorem ipsum dolor sit amet, consectetuer adipiscing elit</span>
						</a></li>
						
						
						<li class="static">IDLE USERS</li>
						<li><a href="#fakelink">
							<span class="user-status warning"></span>
							<img src="assets/img/avatar/avatar.jpg" class="ava-sidebar img-circle" alt="Avatar">
							<i class="fa fa-windows device-status"></i>
							Elizabeth Owens
							<span class="small-caps">2 hours</span>
						</a></li>
						
						
						<li class="static">OFFLINE USERS</li>
						<li><a href="#fakelink">
							<span class="user-status danger"></span>
							<img src="assets/img/avatar/avatar.jpg" class="ava-sidebar img-circle" alt="Avatar">
							Craig Dixon
							<span class="small-caps">Last seen 2 hours ago</span>
						</a></li>
						
					</ul>
				  </div>
				  <div class="tab-pane fade" id="notification-sidebar">
					<ul class="sidebar-menu sidebar-notification">
						<li class="static">TODAY</li>
						<li><a href="#fakelink" data-toggle="tooltip" title="Maria Simpson" data-placement="left">
							<img src="assets/img/avatar/avatar.jpg" class="ava-sidebar img-circle" alt="Avatar">
							<span class="activity">Change her avatar</span>
							<span class="small-caps">20 hours ago</span>
						</a></li>
						<li class="static">YESTERDAY</li>
						<li><a href="#fakelink" data-toggle="tooltip" title="Jason Crawford" data-placement="left">
							<img src="assets/img/avatar/avatar.jpg" class="ava-sidebar img-circle" alt="Avatar">
							<span class="activity">Posted something on your profile page</span>
							<span class="small-caps">Yesterday 10:45:12</span>
						</a></li>
						<li class="static text-center"><button class="btn btn-primary btn-sm">See all notifications</button></li>
					</ul>
				  </div>
				  <div class="tab-pane fade" id="task-sidebar">
					<ul class="sidebar-menu sidebar-task">
						<li class="static">UNCOMPLETED</li>
						<li><a href="#fakelink" data-toggle="tooltip" title="in progress" data-placement="left">
							<i class="fa fa-clock-o icon-task-sidebar progress"></i>
							In progress task
							<span class="small-caps">Deadline : Next week</span>
						</a></li>
						<li><a href="#fakelink" data-toggle="tooltip" title="uncompleted" data-placement="left">
							<i class="fa fa-exclamation-circle icon-task-sidebar uncompleted"></i>
							Uncompleted task
							<span class="small-caps">Deadline : 2 hours ago</span>
						</a></li>
						
						
						<li class="static">COMPLETED</li>
						<li><a href="#fakelink" data-toggle="tooltip" title="completed" data-placement="left">
							<i class="fa fa-check-circle-o icon-task-sidebar completed"></i>
							Completed task
							<span class="small-caps">Completed : 10 hours ago</span>
						</a></li>
						
						
						<li class="static text-center"><button class="btn btn-success btn-sm">See all tasks</button></li>
					</ul>
				  </div><!-- /#task-sidebar -->
				  <div class="tab-pane fade" id="setting-sidebar">
					<ul class="sidebar-menu">
						<li class="static">ACCOUNT SETTING</li>
						<li class="text-content">
							<div class="switch">
								<div class="onoffswitch blank">
									<input type="checkbox" name="onoffswitch" class="onoffswitch-checkbox" id="onoffswitch3" checked>
									<label class="onoffswitch-label" for="onoffswitch3">
										<span class="onoffswitch-inner"></span>
										<span class="onoffswitch-switch"></span>
									</label>
								</div>
							</div>
							Example on off switch
						</li>
						<li class="text-content">
							<div class="switch">
								<div class="onoffswitch blank">
									<input type="checkbox" name="onoffswitch" class="onoffswitch-checkbox" id="onoffswitch4">
									<label class="onoffswitch-label" for="onoffswitch4">
										<span class="onoffswitch-inner"></span>
										<span class="onoffswitch-switch"></span>
									</label>
								</div>
							</div>
							Example on off switch
						</li>
					</ul>
				  </div><!-- /#setting-sidebar -->
				</div><!-- /.tab-content -->
			</div><!-- /.sidebar-right -->
			<!-- END SIDEBAR RIGHT -->
			
			
			
			<!-- BEGIN PAGE CONTENT -->
			<div class="page-content">
				
				<div id="page-wrapper">
					@yield('content')
				</div>
				
				<!-- BEGIN FOOTER -->
				<footer>
					&copy; 2014 <a href="#fakelink">Your company</a>
				</footer>
				<!-- END FOOTER -->
				
				
			</div><!-- /.page-content -->
		</div><!-- /.wrapper -->
		<!-- END PAGE CONTENT -->
		
		
	
		
		
		
		<!--
		===========================================================
		END PAGE
		===========================================================
		-->
		
		<!--
		===========================================================
		Placed at the end of the document so the pages load faster
		===========================================================
		-->
		<!-- MAIN JAVASRCIPT (REQUIRED ALL PAGE)-->
		<script src="/assets/js/jquery.min.js"></script>
		<script src="/assets/js/bootstrap.min.js"></script>
		<script src="/assets/plugins/retina/retina.min.js"></script>
		<script src="/assets/plugins/nicescroll/jquery.nicescroll.js"></script>
		<script src="/assets/plugins/slimscroll/jquery.slimscroll.min.js"></script>
		<script src="/assets/plugins/backstretch/jquery.backstretch.min.js"></script>
 
		<!-- PLUGINS -->
		<script src="/assets/plugins/skycons/skycons.js"></script>
		<script src="/assets/plugins/prettify/prettify.js"></script>
		<script src="/assets/plugins/magnific-popup/jquery.magnific-popup.min.js"></script>
		<script src="/assets/plugins/owl-carousel/owl.carousel.min.js"></script>
		<script src="/assets/plugins/chosen/chosen.jquery.min.js"></script>
		<script src="/assets/plugins/icheck/icheck.min.js"></script>
		<script src="/assets/plugins/datepicker/bootstrap-datepicker.js"></script>
		<script src="/assets/plugins/timepicker/bootstrap-timepicker.js"></script>
		<script src="/assets/plugins/mask/jquery.mask.min.js"></script>
		<script src="/assets/plugins/validator/bootstrapValidator.min.js"></script>
		<script src="/assets/plugins/datatable/js/jquery.dataTables.min.js"></script>
		<script src="/assets/plugins/datatable/js/bootstrap.datatable.js"></script>
		<script src="/assets/plugins/summernote/summernote.min.js"></script>
		<script src="/assets/plugins/markdown/markdown.js"></script>
		<script src="/assets/plugins/markdown/to-markdown.js"></script>
		<script src="/assets/plugins/markdown/bootstrap-markdown.js"></script>
		<script src="/assets/plugins/slider/bootstrap-slider.js"></script>
		
		<!-- EASY PIE CHART JS -->
		<script src="/assets/plugins/easypie-chart/easypiechart.min.js"></script>
		<script src="/assets/plugins/easypie-chart/jquery.easypiechart.min.js"></script>
		
		<!-- KNOB JS -->
		<!--[if IE]>
		<script type="text/javascript" src="assets/plugins/jquery-knob/excanvas.js"></script>
		<![endif]-->
		<script src="/assets/plugins/jquery-knob/jquery.knob.js"></script>
		<script src="/assets/plugins/jquery-knob/knob.js"></script>

		<!-- FLOT CHART JS -->
		<script src="/assets/plugins/flot-chart/jquery.flot.js"></script>
		<script src="/assets/plugins/flot-chart/jquery.flot.tooltip.js"></script>
		<script src="/assets/plugins/flot-chart/jquery.flot.resize.js"></script>
		<script src="/assets/plugins/flot-chart/jquery.flot.selection.js"></script>
		<script src="/assets/plugins/flot-chart/jquery.flot.stack.js"></script>
		<script src="/assets/plugins/flot-chart/jquery.flot.time.js"></script>

		<!-- MORRIS JS -->
		<script src="/assets/plugins/morris-chart/raphael.min.js"></script>
		<script src="/assets/plugins/morris-chart/morris.min.js"></script>
		
		<!-- C3 JS -->
		<script src="/assets/plugins/c3-chart/d3.v3.min.js" charset="utf-8"></script>
		<script src="/assets/plugins/c3-chart/c3.min.js"></script>
		
		<!-- MAIN APPS JS --> 
		<script src="/assets/js/sections/common.js"></script>
		
	</body>
</html>
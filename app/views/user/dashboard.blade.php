@extends('layouts.default')

@section('content')

<div class="container-fluid">

	<!-- Begin page heading -->
	<h1 class="page-heading">{{ Lang::get('ui.dashboard') }}</h1>
	<!-- End page heading -->

	<div id="message">
	{{ Messages::show() }} 
	</div>

	<div class="row dashboard-charts">

	{{ $charts }}

	</div><!-- /.row -->

@stop
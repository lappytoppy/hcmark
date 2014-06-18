<?php
try
{
    $group = Sentry::getUser()->groups->first()->name;
}
catch (Cartalyst\Sentry\Users\UserNotFoundException $e)
{
    echo 'User was not found.';
}

$links = Config::get("template.sidebar_link.$group");

?>
<!-- BEGIN SIDEBAR LEFT -->
<div class="sidebar-left sidebar-nicescroller">
    <ul class="sidebar-menu">
		@foreach($links as $link)
        <li{{ $link['route'] == Route::currentRouteName() ? ' class="active"' : '' }}>
        	<a href="{{ route($link['route']) }}">
        		<i class="{{ $link['class'] }}"></i>
        		{{ Lang::get($link['lang']) }}
        	</a>
        </li>
        @endforeach
    </ul>
</div><!-- /.sidebar-left -->
<!-- END SIDEBAR LEFT -->
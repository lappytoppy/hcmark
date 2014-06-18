<?php

/*
|--------------------------------------------------------------------------
| Application & Route Filters
|--------------------------------------------------------------------------
|
| Below you will find the "before" and "after" events for the application
| which may be used to do any work before or after a request into your
| application. Here you may also register your custom route filters.
|
*/

App::before(function($request)
{
	//
});


App::after(function($request, $response)
{
	//
});

/*
|--------------------------------------------------------------------------
| Authentication Filters
|--------------------------------------------------------------------------
|
| The following filters are used to verify that the user of the current
| session is logged into this application. The "basic" filter easily
| integrates HTTP Basic authentication for quick, simple checking.
|
*/

Route::filter('auth', function()
{ 
    if (!Sentry::check())
    {
        header("Need-Auth: 1");
        Messages::set(Lang::get('messages.not-loggedin'), 'danger');
        return Redirect::guest('/');
    }

});

Route::filter('auth.user', function()
{ 
    if (!Sentry::check())
    {
        header("Need-Auth: 1");
        return Redirect::route('login');
    }
	
	$user_group = Sentry::findGroupByName('user');	
	$isUser = Sentry::getUser()->inGroup($user_group);
	
	if (!$isUser)
	{
		return Redirect::route('admin.dashboard');
	}
});

Route::filter('auth.admin', function()
{ 
    if (!Sentry::check())
    {
        header("Need-Auth: 1");
        return Redirect::route('login');
    }
	
	$admin_group = Sentry::findGroupByName('admin');	
	$isAdmin = Sentry::getUser()->inGroup($admin_group);
	
	if (!$isAdmin)
	{
		return Redirect::route('dashboard');
	}
});


Route::filter('auth.basic', function()
{
	return Auth::basic();
});

// Check if user is authenticated
Route::filter('auth.already', function()
{
    if(Sentry::check())
    {
        $user = Sentry::getUser();
        $user_group = Sentry::findGroupByName('user');
        $admin_group = Sentry::findGroupByName('admin');
        if($user->inGroup($user_group)) 
        { 
            return Redirect::guest('/dashboard');
        }

        if($user->inGroup($admin_group)) 
        {    
          return Redirect::guest('/admin.dashboard');
        }
    } 
    else 
    {
    	Messages::set(Lang::get('messages.not-loggedin'), 'danger');
        return Redirect::guest('/login');
    }
});

/*
|--------------------------------------------------------------------------
| Guest Filter
|--------------------------------------------------------------------------
|
| The "guest" filter is the counterpart of the authentication filters as
| it simply checks that the current user is not logged in. A redirect
| response will be issued if they are, which you may freely change.
|
*/

Route::filter('guest', function()
{
	if (Sentry::check()) return Redirect::to('/');
});

/*
|--------------------------------------------------------------------------
| CSRF Protection Filter
|--------------------------------------------------------------------------
|
| The CSRF filter is responsible for protecting your application against
| cross-site request forgery attacks. If this special token in a user
| session does not match the one given in this request, we'll bail.
|
*/

Route::filter('csrf', function()
{
	if (Session::token() != Input::get('_token'))
	{
		throw new Illuminate\Session\TokenMismatchException;
	}
});
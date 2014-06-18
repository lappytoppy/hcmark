<?php

/*
|--------------------------------------------------------------------------
| Application Routes
|--------------------------------------------------------------------------
|
| Here is where you can register all of the routes for an application.
| It's a breeze. Simply tell Laravel the URIs it should respond to
| and give it the Closure to execute when that URI is requested.
|
*/

Route::get 			('/', 						array('as' => 'home',  							'uses' => 'SessionsController@index' 		));
Route::get 			('login', 					array('as' => 'login_view', 					'uses' => 'SessionsController@view_login'	));
Route::post 		('login', 					array('as' => 'login',  	'before' => 'csrf', 'uses' => 'SessionsController@login'		));
Route::get 			('logout', 					array('as' => 'logout',  						'uses' => 'SessionsController@logout' 		));

Route::group(array 	('prefix' => 'admin', 'before' => 'auth.admin'), function()
{
	
	Route::get 		('dashboard', 				array('as' => 'admin.dashboard', 				'uses' => 'AdminController@index' 			));
	Route::get 		('users', 					array('as' => 'admin.users', 					'uses' => 'AdminController@users' 			));
	Route::get 		('user_list', 				array('as' => 'admin.user_list', 				'uses' => 'AdminController@user_list_api' 	));
	Route::get      ('loggin_as/{id}',          array('as' => 'admin.loggin_as',                'uses' => 'AdminController@loggin_as'       ))
                    ->where('id', '[0-9]+');
    Route::get      ('properties',              array('as' => 'admin.properties',               'uses' => 'AdminController@properties'      ));
    Route::get      ('propapi',                 array('as' => 'admin.propertiesListApi',        'uses' => 'AdminController@propertiesListApi'));
    Route::post     ('propstr',                 array('as' => 'admin.propstr',                  'uses' => 'AdminController@propertiesStore'));
    
	Route::post 	('add_user', 				array('as' => 'admin.add_user', 				'uses' => 'AdminController@add_user' 		));
	Route::post 	('edit_user', 				array('as' => 'admin.edit_user', 				'uses' => 'AdminController@edit_user'		)); 
	Route::post 	('store_user', 				array('as' => 'admin.store_user', 				'uses' => 'AdminController@store_user'		));
    Route::post     ('del_user',				array('as' => 'admin.delete_user',              'uses' => 'AdminController@delete_user'     ));
    Route::post     ('suspend',                 array('as' => 'admin.suspend',                  'uses' => 'AdminController@suspend'         ));
    Route::post     ('custm_mdl',               array('as' => 'admin.customize_modal',          'uses' => 'AdminController@cusomize_modal'  )); 
    Route::post     ('custm_save',              array('as' => 'admin.custm_save',               'uses' => 'AdminController@custm_save'      )); 

});

Route::group(array 	('before' => 'auth.user'), function()
{
	
	Route::get 		('dashboard', 				array('as' => 'dashboard', 						'uses' => 'UserController@dashboard' 		));
	Route::post ('dashboard/refresh_chart', array('uses' => 'UserController@refresh_dashboard_chart'));

});

Route::get 			('account', 				array('as' => 'account', 	'before' => 'auth', 'uses' => 'SessionsController@edit'			));

Route::get          ('account_edit',            array('as' => 'account_edit','before'=>'auth',  'uses' => 'SessionsController@edit_modal'   ));

Route::get 			('register', 				array('as' => 'register', 						'uses' => 'SessionsController@create'		));
Route::get 			('forgot', 					array('as' => 'forgot', 						'uses' => 'SessionsController@forgot'		));
Route::post 		('forgot_send', 			array('as' => 'forgot_send', 					'uses' => 'SessionsController@send_token'	));
Route::get 			('reset/{email}/{code}',	array('as' => 'reset', 							'uses' => 'SessionsController@reset'		));
Route::post 		('reset_save', 				array('as' => 'reset_save', 					'uses' => 'SessionsController@reset_save'	));

Route::resource 	('user', 'SessionsController');
Route::post         ('user_update',             array('as' => 'user_update',                    'uses' => 'SessionsController@update'       ));

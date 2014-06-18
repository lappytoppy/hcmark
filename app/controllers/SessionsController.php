<?php
/**
 * Sessions Controller Class
 *
 * @package Laravel
 * @subpackage Controllers
 * @category Session Controllers
 */
class SessionsController extends BaseController {

    // --------------------------------------------------------------------
    /**
     * Show the form for creating a new resource.
     *
     * @return View
     */
    public function index()
    {
    	if (Sentry::check())
		{
			if ('admin' == Sentry::getUser()->groups->first()->name)
			{
				return Redirect::to('admin/dashboard');
			}
			else
			{
				return Redirect::to('dashboard');
			}
		}
		return Redirect::to('login');
    }

	public function view_login()
	{
        $this->data['meta'] = array(
            'title' => Lang::get('meta.login_title')
            );
        header("Need-Auth: 1");
        return View::make('sessions.login')->with('meta', $this->data['meta']);
	}

    // --------------------------------------------------------------------

    /**
     * Validate credential and login user
     *
     * @return none
     */
    public function login()
    {
        $rules = array(
            'email' => 'required|email',
            'password' => 'required|min:5'
        );

        if(Request::isMethod('post'))
        {
            $data = array(
                       'email' => Input::get('email'),
                       'password' => Input::get('password')
                    );
            $validator = Validator::make($data, $rules);

            //process login error
            if ($validator->fails())
            {
               Messages::set(Lang::get('messages.login_error'), 'danger');
               return Redirect::back()->withInput($data);
            }
            else
            {
                //check throttle status
                try
                {
                    $emptyModelInstance = Sentry::getUserProvider()->getEmptyUser();
                    $user_id = $emptyModelInstance->where('email', '=', $data['email'])->first();
                    if(is_object($user_id))
                    {
                      $throttle = Sentry::findThrottlerByUserId($user_id->id);
                    
                      if ($throttle->check())
                      {
                          try
                          {
                              // Authenticate the user
                              $user = Sentry::authenticate($data, false);
          
                              $view = $this->isAdmin() ? 'admin/dashboard' : 'dashboard';
                              return Redirect::to($view);
                          }
                          catch (Exception $e)
                          {
                              Messages::set(Lang::get('messages.login_error'), 'danger');
                              return Redirect::back()->withInput($data);
                          }
                      }
                    }
                    Messages::set(Lang::get('messages.login_error'), 'danger');
                    return Redirect::back()->withInput($data);
                }
                catch (Cartalyst\Sentry\Users\UserNotFoundException $e)
                {
                    Messages::set(Lang::get('messages.user_not_found'), 'danger');
                }
                catch (Cartalyst\Sentry\Throttling\UserSuspendedException $e)
                {
                    $time = $throttle->getSuspensionTime();
                    Messages::set(trans('messages.user_suspended', array('time',$time)), 'danger');
                }
                catch (Cartalyst\Sentry\Throttling\UserBannedException $e)
                {
                    Messages::set(Lang::get('messages.user_banned'), 'danger');
                }
            }
        }

		return Redirect::to('login');
    }

    // --------------------------------------------------------------------

    /**
     * Register new user with provided detail.
     *
     * @return html
     */
    public function edit()
    {
        $this->data['meta'] = array(
            'title' => Lang::get('meta.account_title')
            );
        return View::make('sessions.edit')
                    ->with('meta', $this->data['meta'])
                    ->with('user', Sentry::getUser());
    }
    
    /*
     * Displays edit modal on global,
     * saves on 'SessionController.update' function
     * 
     */
    public function edit_modal()
    {
        return View::make('sessions.edit_modal', array('user' => Sentry::getUser()));
    }

    // --------------------------------------------------------------------

    /**
     * Update the specified resource in storage.
     *
     * @param  int  $id
     * @return Response
     */
    public function update($id = false)
    {
      if (empty($id))
      {
          $id = Sentry::getUser()->id;
      }
      
      $data = Input::all();
      //validation rule for form data
       $rules = array(
            'full_name' => 'required|min:2',
            'email'     => 'required|email',
        );

       //prepare data for password validation if it is not blank
        if($data['password'] != '') {
            $rules['password'] = 'required|min:5|confirmed';
        }
        
        $json = array('success' => 0, 'message' => Lang::get('messages.general'));

        $validator = Validator::make($data, $rules);

        // process the login
        if ($validator->fails())
        {
            Messages::set(Lang::get('messages.register_error'), 'danger');
            if (Request::ajax())
            {
                return json_encode($json);
            }
            return Redirect::back()->withInput($data);
        }
        else
        {
            // Find the user using the user id
            $user = Sentry::getUser();

            // setting the user details
            //$user->email     = $data['email'];
            $user->full_name = $data['full_name'];
            $user->org_name  = $data['org_name'];
            $user->telephone = $data['telephone'];

            //pepare data with password if it is not blank
            if($data['password'] != '') {
                $user->password = $data['password'];
            }

            //saving user information
            if($user->save())
            {
               $json['success'] = 1;
               $json['message'] = Lang::get('messages.account_update');
               
                Messages::set(Lang::get('messages.account_update'), 'success');
            }
            else
            {
                 Messages::set(Lang::get('messages.general'), 'error');
            }

        }
        
        if (Request::ajax())
        {
            return json_encode($json);
        }
        
        return Redirect::to('/account');
    }

    // --------------------------------------------------------------------

    /**
     * Show the form for creating a new resource.
     *
     * @return Redirect
     */
    public function create()
    {
        $this->data['meta'] = array(
            'title' => Lang::get('meta.register_title')
        );
        return View::make('sessions.create')->with('meta', $this->data['meta']);
    }

    // --------------------------------------------------------------------
    /**
     * register new user.
     *
     * @return Response
     */
    public function store()
    {

      //validation rule for form data
      $rules = array(
        'full_name'         => 'required|min:2',
        'email'             => 'required|email|unique:users',
        'terms_conditions'  => 'required',
        'password'          => 'required|min:5|confirmed'
      );
      
      $data = Input::all();

      $validator = Validator::make($data, $rules);

        try
        {
              // process to validate user
              if ($validator->fails())
              {
                 Messages::set(Lang::get('messages.register_error'), 'danger');
                 return Redirect::back()->withInput($data);
              }
              else
              {
                    unset($data['password_confirmation']);
                    unset($data['login-btn']);
                    unset($data['terms_conditions']);
                    unset($data['_token']);
                    $data['activated']  = true;
                    try
                    {
                        // Create the user
                        $user = Sentry::register($data);

                        //find group interface of user
                       $group = Sentry::findGroupByName('user');
                       //assign default group to user
                       $user->addGroup($group);

                        // Let's get the activation code
                        $activationCode = $user->getActivationCode();

                        Messages::set(Lang::get('messages.register_success'), 'success');
                        return Redirect::to('/');
                    }
                    catch (Cartalyst\Sentry\Users\UserExistsException $e)
                    {
                         Messages::set(Lang::get('messages.general'), 'danger');
                         return Redirect::back()->withInput($data);
                    }

              }
        }
        catch(Exception $e)
        {
            Log::error($e->getMessage() . ' , Method ' . __function__ . '(' . implode(',', func_get_args()) . ')');
            Messages::set(Lang::get('messages.general'), 'danger');
            return Redirect::back()->withInput($data);
        }
    }

    // --------------------------------------------------------------------

    /**
     * forgot password on the basis of email address.
     *
     * @return html
     */
    public function forgot()
    {

        $this->data['meta'] = array(
            'title' => Lang::get('meta.forgot_title')
            );
        return View::make('sessions.forgot_password')->with('meta', $this->data['meta']);
    }

    // --------------------------------------------------------------------

    /**
     * reset password token send on mail.
     *
     * @return html
     */
    public function send_token()
    {

        $this->data['meta'] = array(
            'title' => Lang::get('meta.forgot_title')
            );

       try
        {

            // Find the user using the user email address
            $user = Sentry::findUserByLogin(Input::get('email'));

            // Get the password reset code
            $reset_code = $user->getResetPasswordCode();
            if($reset_code) {
                //prepare subject from and name
                $subject = Lang::get('messages.subject_reset');
                $email = $user['email'];
                $full_name = $user['full_name'];

                $user_info['info'] = array( 'code' => $reset_code, 'user' => $user);

                //send mail with token
                $sent = Mail::send('emails.auth.reset_password', $user_info,
                            function($message) use ($subject, $email, $full_name)
                            {
                                $message->to($email, $full_name)->subject($subject);
                            }
                    );

                Messages::set(Lang::get('ui.reset_sent'), 'success');
                return Redirect::to('/');
            }

        }
        catch (Cartalyst\Sentry\Users\UserNotFoundException $e)
        {
            Messages::set(Lang::get('messages.general'), 'danger');
            return Redirect::back()->withInput();
        }

    }

    // --------------------------------------------------------------------

    /**
     * Reset user password on the basis of reset code.
     *
     * @return html
     */
    public function reset($email, $code)
    {
        $valid_salt = 0;
        $this->data['meta'] = array(
            'title' => Lang::get('meta.reset_title')
            );
        try
        {

            // Find the user using the user id
            $user = Sentry::findUserByLogin($email);
            // Check if the reset password code is valid
            if ($user->checkResetPasswordCode($code))
            {
                 $valid_salt = 1;
            }

            $this->data['meta'] = array(
                'title' => Lang::get('meta.reset_title')
            );

        }
        catch (Cartalyst\Sentry\Users\UserNotFoundException $e)
        {
            Messages::set(Lang::get('messages.general'), 'danger');
        }

        return View::make('sessions.reset')
                            ->with('meta', $this->data['meta'])
                            ->with('salt', $valid_salt)
                            ->with('user_info', array(
                                    'code' => $code,
                                    'email' => $email
                               )
                        );
    }

    // --------------------------------------------------------------------

    /**
     * Update user credential on the basis of code.
     *
     * @return html
     */
    public function reset_save()
    {
        //validation rule for form data
        $rules = array(
            'password' => 'required|min:5|confirmed'
        );
        $data = Input::all();
        $this->data['meta'] = array(
            'title' => Lang::get('meta.reset_title')
            );

        //validating data before saving
        $validator = Validator::make($data, $rules);

        if ($validator->fails()) {
               Messages::set(Lang::get('messages.login_error'), 'danger');
               return Redirect::back()->withInput();
            } else{

                try
                {
                    // Find the user using the user id
                    $user = Sentry::findUserByLogin(Input::get('email'));
                    $code = Input::get('code');
                    // Check if the reset password code is valid
                    if ($user->checkResetPasswordCode($code))
                    {
                         // Attempt to reset the user password
                        if ($user->attemptResetPassword($code, Input::get('password')))
                        {
                             Messages::set(Lang::get('ui.reset_success'), 'success');
                             return Redirect::route('login');
                        }
                        else
                        {
                            throw new Exception("Invalid detail1", 1);
                        }

                    } else {
                         throw new Exception("Invalid detail2", 1);
                    }
                }
                catch (Cartalyst\Sentry\Users\UserNotFoundException $e)
                {
                    Messages::set(Lang::get('messages.general'), 'danger');
                    return Redirect::back()->withInput($data);
                }
            }

    }

    // --------------------------------------------------------------------

    /**
     * logout user and reset session
     *
     * @return none
     */
    public function logout()
    {
        $admin_id = false;

        if (Session::has('admin_id'))
        {
            $admin_id = Session::get('admin_id');
            Session::forget('admin_id');
        }

        Sentry::logout();

        if ($admin_id)
        {
            $admin_user = Sentry::findUserById($admin_id);
            Sentry::login($admin_user);
            return Redirect::route('admin.dashboard');
        }

        return Redirect::to('/');
    }

    // --------------------------------------------------------------------

    /**
     * set preferences for users
     *
     * @return none
     */
    public function preferences()
    {

        return Redirect::to('/');
    }
}

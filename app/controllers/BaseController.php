<?php

class BaseController extends Controller {
	protected $layout = 'layouts.guest';

	// Global array for method interaction
    public $data = array();

    /**
	 * Collect userr information into data array.
	 *
	 * @return none
	 */
	public function __construct()
    {
        // Assign user data to global array 
    }

    // --------------------------------------------------------------------
	/**
	 * Setup the layout used by the controller.
	 *
	 * @return void
	 */
	protected function setupLayout()
	{
		if ( ! is_null($this->layout))
		{
			$this->layout = View::make($this->layout);
		}
	}

	// --------------------------------------------------------------------

	/**
	 * Get current group name of user.
	 *
	 * @return string group name
	 */
	protected function getGroup()
	{ 
		$groups = Sentry::getUser()->getGroups();
		return $groups[0]->name;
	}

	// --------------------------------------------------------------------

	/**
	 * check if user is admin or not
	 *
	 * @return bool ture/false
	 */
	public function isAdmin()
	{	
		$admin_group = Sentry::findGroupByName('admin');	
		return Sentry::getUser()->inGroup($admin_group);
	}

	// --------------------------------------------------------------------

	/**
	 * check if user is guest or not
	 *
	 * @return bool ture/false
	 */
	public function isUser()
	{	
		$user_group = Sentry::findGroupByName('user');	
		return Sentry::getUser()->inGroup($user_group);
	}

}
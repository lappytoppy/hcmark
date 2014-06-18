<?php

use Illuminate\Auth\UserInterface;
use Illuminate\Auth\Reminders\RemindableInterface;
use Cartalyst\Sentry\Users\Eloquent\User as SentryUser;
use Illuminate\Database\Eloquent\SoftDeletingTrait;

class User extends SentryUser {

	use SoftDeletingTrait;

	/**
	 * The database table used by the model.
	 *
	 * @var string
	 */
	protected $table = 'users';

	/**
	 * The attributes excluded from the model's JSON form.
	 *
	 * @var array
	 */
	protected $hidden = array('password');
	/**
	 * Get the unique identifier for the user.
	 *
	 * @return mixed
	 */
	public function getAuthIdentifier()
	{
		return $this->getKey();
	}

	/**
	 * Get the password for the user.
	 *
	 * @return string
	 */
	public function getAuthPassword()
	{
		return $this->password;
	}

	/**
	 * Get the e-mail address where password reminders are sent.
	 *
	 * @return string
	 */
	public function getReminderEmail()
	{
		return $this->email;
	}
    
    public function features()
    {
        return $this->belongsToMany('Features', 'user_features', 'user_id', 'feature_id');
    }
    
    public function properties()
    {
        return $this->belongsToMany('Properties', 'users_properties', 'user_id', 'property_id');
    }
    
    public function group()
    {
        return $this->belongsToMany('Group', 'users_groups');
    }
    
    // Override the SentryUser getPersistCode method.

    public function getPersistCode()
    {
        if (!$this->persist_code)
        {
            $this->persist_code = $this->getRandomString();

            // Our code got hashed
            $persistCode = $this->persist_code;

            $this->save();

            return $persistCode;            
        }
        return $this->persist_code;
    }

}
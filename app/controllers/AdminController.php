<?php
/**
 * Sessions Controller Class
 *
 * @package Laravel
 * @subpackage Controllers
 * @category Admin Controllers
 */
class AdminController extends BaseController {

    // --------------------------------------------------------------------
    
	public function adminAuth()
	{
		if (!$this->isAdmin())
		{
			return Redirect::to('/');
		}
	}
	
    /**
     * Show the form for creating a new resource.
     *
     * @return View
     */ 
    public function index()
    {
		return View::make('admin.index');
    }
	
	/*
	 * Display users
	 * 
	 */
	public function users()
	{
		$this->data['meta'] = array(
            'title' => Lang::get('meta.dashboard_title')
            ); 
        $group = Group::g_list();
        $features = Features::g_list();
        $properties = Properties::g_list();
        return View::make('admin.users.index')
                ->with('meta', $this->data['meta'])
                ->with('group', $group)
                ->with('features',$features)
                ->with('properties',$properties);
	}
	
    // --------------------------------------------------------------------
    
    /**
	 *
	 * API 
	 *
     * Show the form for creating a new resource.
     *
     * @return View
     */ 
    public function user_list_api()
    {   
        
        $this->data['meta'] = array(
            'title' => Lang::get('meta.dashboard_title')
            );
        
        $cols = array(
            'full_name',
            'email',
            'name', /* group name e.g. Admin, User */
            'suspended', /* active or not */
            'email',
        );    
        
        // Sort by
        $keywords = Input::get('sSearch');
        $sortOrder = Input::get('sSortDir_0');
        $sortBy = Input::get('iSortCol_0');
        if ($sortBy >= count($cols))
        {
            $sortBy = $cols[0];
        }
        else
        {
            $sortBy = $cols[$sortBy];
        }
        
        //default sort direction
        if (!in_array($sortOrder, array('desc','asc'))){
            $sortOrder = 'asc';
        }
        
        $user = SP::users($keywords, $sortBy, $sortOrder, Input::get('iDisplayLength'), Input::get('iDisplayStart'));
        return View::make('admin.user_list', array('user' => $user));
    } 
    
    
    // --------------------------------------------------------------------
    
    /**
     * create new user and assign role to user.
     *
     * @return Response
     */
    public function add_user()
    {
      
      $data = Input::all();
      
        try 
        {       $data['activated']  = true; 
                try
                {
                   //find group interface of user
                   $group = Sentry::findGroupByName($data['group']);
                   $features = false;
                   $properties = false;
                   
                   if (isset($data['features'])){
                       $features = $data['features'];
                       unset($data['features']);
                   }
                   
                   if (isset($data['properties'])){
                       $properties = $data['properties'];
                       unset($data['properties']);
                   }
                   
                    unset($data['group']);
                    // Create the user
                    $user = Sentry::register($data);
                    
                    //assign default group to user
                    $user->addGroup($group);
                    
                    //save features
                    if (is_array($features) && count($features)){
                        Features::saveByUser($user->id, $features);
                    }
                    
                    //save properties
                    if (is_array($properties) && count($properties)){
                        Properties::saveByUser($user->id, $properties);
                    }
                    
                    // Let's get the activation code
                    $activationCode = $user->getActivationCode();
                    $result = array('response' => array('type'=> 'success', 'message' => Lang::get('messages.register_success')) ); 
                }
                catch (Cartalyst\Sentry\Users\UserExistsException $e) 
                {       
                     $result = array('response' => array('type'=> 'danger', 'message' => Lang::get('messages.general')) );
                }
               return json_encode($result);
        } 
        catch(Exception $e) 
        {
            Log::error($e->getMessage() . ' , Method ' . __function__ . '(' . implode(',', func_get_args()) . ') Data:' . print_r($data,1) );  
            $result = array('response' => array('type'=> 'danger', 'message' => Lang::get('messages.general')) );
            return json_encode($result);
        }
    }
    
     // --------------------------------------------------------------------
    
    /**
     * create new user and assign role to user.
     *
     * @return Response
     */
    public function edit_user()
    { 
       $user_info =  User::find(Input::get('id'));
       
       $group = Group::g_list();
       $features = Features::g_list();
       $properties = Properties::g_list();
       
       return View::make('admin.edit_user', array(
                        'user'       => $user_info,
                        'group'      => $group,
                        'features'   => $features,
                        'properties' => $properties
                    ));
    }

    public function delete_user()
    {
        $result = array('type'=>'danger','message'=>Lang::get('messages.general'));

        $id = Input::get('id');
        
        if ($id)
        {
            $user = User::find($id);

            if ($user){
              $user->delete();
              $result['type'] = 'danger';
              $result['message'] = Lang::get('messages.success_delete');
            }
        }

        return json_encode($result);
    }
    
    // --------------------------------------------------------------------
    
    /**
     * update user and assign role to user.
     *
     * @return Response
     */
    public function store_user()
    { 
        $data = Input::all();
        // Find the user using the user id
        $user = Sentry::findUserById($data['id']); 
      
        //pepare data with email if it is not blank
        if($data['email'] != '')
        {
            $user->email = $data['email'];
        } 
        
        //pepare data with full_name if it is not blank
        if($data['full_name'] != '')
        {
            $user->full_name = $data['full_name'];
        } 
        
        //pepare data with password if it is not blank
        if($data['password'] != '')
        {
            $user->password = $data['password'];
        }
		
		if (isset($data['org_name']))
		{
			$user->org_name = $data['org_name'];
		}
		
		if (isset($data['telephone']))
		{
            $user->telephone = $data['telephone'];
		}
		
		if (isset($data['notes']))
		{
            $user->notes = $data['notes'];
		}
        
        //save features
        if (isset($data['features']) && is_array($data['features'])){
            Features::saveByUser($data['id'], $data['features']);
        } else {
            Features::clearByUser($data['id']);
        }
        
        //save properties
        if (isset($data['properties']) && is_array($data['properties'])){
            Properties::saveByUser($data['id'], $data['properties']);
        } else {
            Properties::clearByUser($data['id']);
        }
		
        //saving user information
        if($user->save()) 
        {
            $response = array('type'=> 'success', 'message' => Lang::get('messages.account_update'));
            Messages::set(Lang::get('messages.account_update'), 'success');
        }
        else
        {   
            Messages::set(Lang::get('messages.general'), 'error');   
            $response = array('type'=> 'error', 'message' => Lang::get('messages.general'));
        }
		
		
		//remove old groups
		$groups = $user->getGroups()->toArray();
		foreach ($groups as $g)
		{
			$user->removeGroup(Sentry::findGroupById($g['pivot']['group_id']));
		}
			
		//save role
		if ($new_group = Sentry::findGroupByName($data['group']))
		{
			if(!$user->addGroup($new_group))
	        {
	           Messages::set(Lang::get('messages.general'), 'error');   
	           $response = array('type'=> 'error', 'message' => Lang::get('messages.group_update'));
	        }
		}
        
        $result = array('response' => $response);
        return json_encode($result);
    }
    
    public function loggin_as($id)
    {
        try
        {
            Session::put('admin_id', Sentry::getUser()->id);
            
            $user = Sentry::findUserById($id);
            Sentry::login($user);
            
            $admin = Sentry::findGroupByName('admin');
            
            if ($user->inGroup($admin))
            {
                return Redirect::route('admin.dashboard');
            }
            else
            {
                return Redirect::route('dashboard');
            }
        }
        catch (Cartalyst\Sentry\Users\UserNotFoundException $e)
        {
            return Redirect::back();
        }
    }
    
    public function suspend()
    {
        $id = $name = Input::get('id');
        $set = $name = Input::get('set');
        $result = array('success' => 0, 'message' => '');
        try
        {
            $user = Sentry::findThrottlerByUserId($id);
            if (!$set){
                $user->suspend();
                $result['message'] = 'User suspended';
            } else {
                $user->unsuspend();
                $result['message'] = 'User unsuspended';
            }
            $result['success'] = 1;
        }
        catch (Cartalyst\Sentry\Users\UserNotFoundException $e)
        {
            $result['message'] = 'User not found';
        }
        
        return json_encode($result);
    }
    
    public function properties()
    {
        $property_types = Property_types::g_list();
        $star_ratings   = Star_ratings::g_list();
        $pms_configs    = Pms_configs::g_list();
        return View::make('admin.properties.index')
                   ->with('property_types', $property_types)
                   ->with('star_ratings', $star_ratings)
                   ->with('pms_configs', $pms_configs);
    }

    public function propertiesListApi()
    {
        $inp = Input::all();
        $id  = Input::get('id');
        if ($id){
            $properties = Properties::find($id);
        } else {
            $properties = Properties::all();
        }
        return View::make('admin.properties.propertyList',
            array('properties' => $properties,
                  'input'      => $inp,
                  'id'         => $id
        ));
    }
    
    public function propertiesStore()
    {
        $out = array('message' => Lang::get('messages.general'),'type'=>'danger');
        $data = Input::all();
        
        
        $id = Input::get('id');
        
        if ($id)
        {
            $prop = Properties::find($id);
            if (!$prop){
                $out['message'] = Lang::get('messages.general');
                return json_encode($out);
            }
            
            if (Input::get('_delete')){
                $prop->delete();
                $out['type']    = 'success';
                $out['message'] = Lang::get('messages.success_delete');
                return json_encode($out);
            }
        }
        else
        {
            $prop = new Properties;
        }
        
        if (!isset($data['property_name']) || empty($data['property_name']))
        {
            return json_encode($out);
        }
        
        $cols = array('property_name',
                      'full_name',
                      'telephone',
                      'email',
                      'notes',
                      'property_type_id',
                      'star_rating_id',
                      'pms_config_id',
                      'pms_account_ref'
                    );
        
        foreach ($cols as $c){
            if (isset($data[$c]))
            {
                $prop->$c = $data[$c];
            }
        }
        
        $prop->save();
        $out['type']      = 'success';
        
        if ($id)
        {
            $out['message']   = Lang::get('messages.success_update');
        }
        else
        {
            $out['message']   = Lang::get('messages.success_add');
            $out['clear']     = true;
        }
        
        return json_encode($out);
    }
    
    public function cusomize_modal()
    {
        $id = Input::get('id', false);
        
        if (!$id)
        {
            return Lang::get('messages.invalid_request');
        }
        
        $user  = User::find($id);
        $image = Customisation::where('user_id', '=', $id)->orderBy('created_at', 'desc')->first();
        
        return View::make('admin.customisation_modal', array('user' => $user, 'image' => $image));
    }
    
    public function custm_save()
    {
        $result = array(
                      'type'=> 'danger',
                      'message' => Lang::get('messages.general')
                  );
        
        $usrId = Input::get('usr_id');
        
        if (!$usrId)
        {
            return json_encode($result);
        }
        
        if (Input::hasFile('image_file')){
            $options = array(
                'upload_dir' => Config::get('upload.images.upload_dir'),
                'upload_url' => Config::get('upload.images.upload_url'),
                'param_name' => 'image_file',
                'readfile_chunk_size' => 1024 * 1024,
                'image_versions' => array(
                    '' => array(
                        // Automatically rotate images based on EXIF meta data:
                        'auto_orient' => true,
                        'max_width' => 500,
                        'max_height' => 500
                    ),
                )
            );
            $messages = Config::get('messages.jquery_image_uploader');
            
            $Jqueryupload = new Jqueryupload($options, false, $messages);
            
            $res = $Jqueryupload->post(false);
            
            if (!count($res[$options['param_name']])){
                return json_encode($result);
            }
            
            $filename = $res[$options['param_name']][0]->name;
            
            $url = Config::get('upload.images.placeholder');
            
            if (!isset($res[$options['param_name']][0]->url)){
                $result['message'] = Lang::get('messages.jquery_image_uploader.max_file_size');
            } else {
                $url = $res[$options['param_name']][0]->url;
                
                $cust = new Customisation;
                $cust->user_id = $usrId;
                $cust->logo = $filename;
                $cust->save();
                
                $result['type'] = 'success';
                $result['message'] = Lang::get('messages.success_image_upload');
                $result['name'] = $filename;
                $result['url'] = $url;
            }
        }
        
        return json_encode($result);
    }
}

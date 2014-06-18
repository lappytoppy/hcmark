<?php 

class Group extends Eloquent {

    /**
     * The database table used by the model.
     *
     * @var string
     */
    protected $table = 'groups';  
    
    public static function g_list() 
    {
        $groups = Group::all(array('id', 'name'));
        $list = array();
        foreach($groups as $group)
        {
            $list[$group->name] = ucfirst($group->name);
        }
        return $list;
    }
    
    public function users()
    {
        return $this->belongsToMany('User');
    }

}
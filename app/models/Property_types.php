<?php 

class Property_types extends Eloquent {

    /**
     * The database table used by the model.
     *
     * @var string
     */
    protected $table = 'property_types';  

    public $timestamps = false;
    
    public static function g_list() 
    {
        $results = Property_types::all(array('id', 'name','show_stars'));
        $list = array();
        foreach($results as $result)
        {
            $list[$result->id] = (object)array('name' => ucfirst($result->name), 'show_stars' => $result->show_stars);
        }
        return $list;
    }
}
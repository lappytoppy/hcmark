<?php 

class Star_ratings extends Eloquent {

    /**
     * The database table used by the model.
     *
     * @var string
     */
    protected $table = 'star_ratings';  

    public $timestamps = false;
    
    public static function g_list() 
    {
        $results = Star_ratings::all(array('id', 'name'));
        $list = array();
        foreach($results as $result)
        {
            $list[$result->id] = ucfirst($result->name);
        }
        return $list;
    }
}
<?php 

use Illuminate\Database\Eloquent\SoftDeletingTrait;

class Properties extends Eloquent {

    /**
     * The database table used by the model.
     *
     * @var string
     */
     
    use SoftDeletingTrait;

    protected $dates = ['deleted_at'];
    
    protected $table = 'properties';
    
    public static function g_list() 
    {
        $properties = Properties::select(array('id', 'property_name'))->whereNull('deleted_at')->get();
        $list = array();
        foreach($properties as $p)
        {
            $list[$p->id] = ucfirst($p->property_name);
        }
        return $list;
    }
    
    public static function saveByUser($userId, $ids = array())
    {
        $ids = array_unique($ids);
        
        DB::delete('DELETE from users_properties where user_id =' . $userId);
        
        $insert = array();
        
        if (count($ids))
        {
            foreach ($ids as $id)
            {
                $insert[] = array('user_id' => $userId, 'property_id' => $id);
            }
            
            DB::table('users_properties')->insert($insert);
        }
    }
    
    public static function clearByUser($userId)
    {
        DB::delete('DELETE from users_properties where user_id =' . $userId);
    }
}
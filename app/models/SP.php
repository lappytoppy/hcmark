<?php
/**
 * SP(Stored Procedure) Model Class
 *
 * @package Laravel
 * @subpackage Models
 * @category SP Model
 */
class SP extends Eloquent {
 
    // --------------------------------------------------------------------

    
    /**
     * Reterive users,
     *
     * @param  string  $search
     * @param  number  $limit
     * @param  number  $offset
     * @param  string  $sort
     * @param  string  $order
     * @return array   $result
     */
    public static function users( 
        $keyword = '', 
        $sort = 'email', 
        $order = '1',
        $limit = 10,
        $offset = 0
        ){ 
        global $word;
        $word = $keyword ;
        try {
            $q = DB::table('users')
                ->leftJoin('users_groups', 'users.id', '=', 'users_groups.user_id')
                ->leftJoin('groups', 'groups.id', '=', 'users_groups.group_id')
                ->leftJoin(DB::raw('(SELECT * FROM throttle GROUP BY throttle.user_id) as th'), 'users.id', '=', 'th.user_id')
                ->select('users.full_name','users.email','activated', 'groups.name', 'users.id', 'th.suspended')
                ->where(function($query){
                     global $word;
                     if(trim($word))   {                       
                        $word = '%' . $word . '%';
                        $query->where('full_name', 'like', $word)
                              ->orWhere('email', 'like', $word )
                              ->orWhere('groups.name', 'like', $word );
                     }
                })
                ->whereNull('deleted_at')
                ->orderBy($sort, $order)
                ->skip($offset)
                ->take($limit);
                
            $users =  $q->get();
 
            $count = DB::table('users_groups')->count();

            $result = array(
                'search' => $users,
                'total' => $count
                );
            return $result;
        } catch(Exception $e) {
            Log::error($e->getMessage());
            var_dump($e->getMessage());
        }
        
    }
    
     /**
     * Reterive user,
     *
     * @param  string  $id
     * @return object $user
     */
    public static function user($id) 
    {
        $user =  DB::table('users_groups')
                ->join('users', 'users.id', '=', 'users_groups.user_id')
                ->join('groups', 'groups.id', '=', 'users_groups.group_id')
                ->select('users.full_name','users.email','activated', 'groups.name', 'users.id', 'org_name', 'telephone', 'notes')
                ->where('users.id', '=', $id) 
                ->take(1)->get();
        return $user;
    }
    
}
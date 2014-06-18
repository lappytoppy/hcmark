<?php

class GroupTableSeeder extends Seeder {

	/**
	 * Run the database seeds.
	 *
	 * @return void
	 */
	public function run()
	{
		$group_count = Group::all()->count();
		if($group_count == 0)
		{
			DB::table('groups')->delete();

	        Group::create(array('name' => 'admin'));
	        Group::create(array('name' => 'user'));
    	}
	}

}
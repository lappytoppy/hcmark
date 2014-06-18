<?php

use Illuminate\Database\Migrations\Migration;

class EditUsers extends Migration {

	/**
	 * Run the migrations.
	 *
	 * @return void
	 */
	public function up()
	{
		Schema::table('users', function($t) {
			$t->dropColumn('first_name');
			$t->dropColumn('last_name');
			$t->string('full_name', 100);
		});
	}

	/**
	 * Reverse the migrations.
	 *
	 * @return void
	 */
	public function down()
	{
		Schema::table('users', function($t) {
			$t->string('first_name', 100);
			$t->string('last_name', 100);
			$t->dropColumn('full_name');
		});
	}

}
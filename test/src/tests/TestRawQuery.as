/*
 * MIT License
 *
 * Copyright (c) 2017 Digital Strawberry LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

package tests
{
	import breezedb.BreezeDb;
	import breezedb.IBreezeDatabase;
	import breezedb.collections.Collection;
	import breezedb.queries.BreezeRawQuery;
	import breezedb.queries.BreezeQueryResult;
	import breezedb.queries.BreezeSQLResult;
	import breezedb.schemas.TableBlueprint;

	import breezetest.Assert;

	import breezetest.async.Async;

	import flash.errors.SQLError;
	
	public class TestRawQuery
	{
		public var currentAsync:Async;

		private var _db:IBreezeDatabase;
		private var _numInserts:int = 0;

		private const _photos:Array = [
			{ title: "Mountains",   views: 35,  downloads: 10 },
			{ title: "Flowers",     views: 6,   downloads: 6 },
			{ title: "Lake",        views: 40,  downloads: 0 },
			{ title: "Camp Fire",   views: 13,  downloads: 13 }
		];
		private const _tableName:String = "photos";


		public function setupClass(async:Async):void
		{
			async.timeout = 2000;

			_db = BreezeDb.getDb("raw-query-test");
			_db.setup(onDatabaseSetup);
		}


		private function onDatabaseSetup(error:Error):void
		{
			Assert.isNull(error);
			Assert.isTrue(_db.isSetup);

			// Create test table
			_db.schema.createTable(_tableName, function(table:TableBlueprint):void
			{
				table.increments("id");
				table.string("title").defaultNull();
				table.integer("views").defaultTo(0);
				table.integer("downloads").defaultTo(0);
			}, onTableCreated);
		}


		private function onTableCreated(error:Error):void
		{
			Assert.isNull(error);

			currentAsync.complete();
		}


		public function testAll(async:Async):void
		{
			async.timeout = 10000;

			// Start with INSERT so that we have some data to work with
			for each(var photo:Object in _photos)
			{
				var query:BreezeRawQuery = new BreezeRawQuery(_db);
				query.insert(
						"INSERT INTO " + _tableName + " (title, views, downloads) VALUES (:title, :views, :downloads)",
						photo,
						onInsertCompleted);
			}
		}


		private function onInsertCompleted(error:Error):void
		{
			Assert.isNull(error);

			_numInserts++;
			if(_numInserts == _photos.length)
			{
				testRawQuery();
			}
		}

		
		private function testRawQuery():void
		{
			var query:BreezeRawQuery = new BreezeRawQuery(_db);
			query.query("SELECT * FROM " + _tableName, onRawQueryCompleted);
		}


		private function onRawQueryCompleted(error:Error, result:BreezeSQLResult):void
		{
			Assert.isNull(error);
			Assert.isNotNull(result);
			Assert.isNotNull(result.data);
			Assert.equals(4, result.data.length);

			var length:int = result.data.length;
			for(var i:int = 0; i < length; ++i)
			{
				Assert.equals(_photos[i].title, result.data[i].title);
				Assert.equals(_photos[i].views, result.data[i].views);
				Assert.equals(_photos[i].downloads, result.data[i].downloads);
			}

			testSelect();
		}


		private function testSelect():void
		{
			var query:BreezeRawQuery = new BreezeRawQuery(_db);
			query.select("SELECT id, title, views FROM " + _tableName, onSimpleSelectCompleted);
		}


		private function onSimpleSelectCompleted(error:Error, results:Collection):void
		{
			Assert.isNull(error);
			Assert.isNotNull(results);
			Assert.equals(4, results.length);

			var query:BreezeRawQuery = new BreezeRawQuery(_db);
			query.select("SELECT id, title, views FROM " + _tableName + " WHERE (id > :id)", { id: 2 }, onAdvancedSelectCompleted);
		}


		private function onAdvancedSelectCompleted(error:Error, results:Collection):void
		{
			Assert.isNull(error);
			Assert.isNotNull(results);
			Assert.equals(2, results.length);

			testUpdate();
		}


		private function testUpdate():void
		{
			var query:BreezeRawQuery = new BreezeRawQuery(_db);
			query.update("UPDATE " + _tableName + " SET title = :title WHERE id = :id", { title: "Trees", id: 2 }, onUpdateCompleted);
		}


		private function onUpdateCompleted(error:Error, rowsAffected:int):void
		{
			Assert.isNull(error);
			Assert.equals(1, rowsAffected);

			// Check if the title has been changed
			var query:BreezeRawQuery = new BreezeRawQuery(_db);
			query.select("SELECT id, title FROM " + _tableName + " WHERE (id = :id)", { id: 2 }, onCheckTitleSelectCompleted);
		}


		private function onCheckTitleSelectCompleted(error:Error, results:Collection):void
		{
			Assert.isNull(error);
			Assert.isNotNull(results);
			Assert.equals(1, results.length);
			Assert.equals("Trees", results[0].title);

			testRemove();
		}


		private function testRemove():void
		{
			var query:BreezeRawQuery = new BreezeRawQuery(_db);
			query.remove("DELETE FROM " + _tableName + " WHERE title = :title", { title: "Trees" }, onDeleteCompleted);
		}


		private function onDeleteCompleted(error:Error, rowsAffected:int):void
		{
			Assert.isNull(error);
			Assert.equals(1, rowsAffected);

			// Check if the item has been deleted
			var query:BreezeRawQuery = new BreezeRawQuery(_db);
			query.select("SELECT id, title FROM " + _tableName, onCheckDeleteCompleted);
		}


		private function onCheckDeleteCompleted(error:Error, results:Collection):void
		{
			Assert.isNull(error);
			Assert.isNotNull(results);
			Assert.equals(3, results.length);

			var length:int = results.length;
			for(var i:int = 0; i < length; ++i)
			{
				Assert.notEquals("Trees", results[i].title);
				Assert.notEquals(2, results[i].id);
			}

			testMultiQuery();
		}


		private function testMultiQuery():void
		{
			var query:BreezeRawQuery = new BreezeRawQuery(_db);
			query.multiQuery([
				"SELECT id, title FROM " + _tableName,
				"DROP TABLEz " + _tableName, // forced error
				"UPDATE " + _tableName + " SET title = :title WHERE id = :id",
				"SELECT id, title FROM " + _tableName + " WHERE title = 'Hills'"
			], [null, null, { title: "Hills", id: 1 }], onMultiQueryCompleted);
		}


		private function onMultiQueryCompleted(results:Vector.<BreezeQueryResult>):void
		{
			Assert.isNotNull(results);
			Assert.equals(4, results.length);

			// First SELECT result
			var result:BreezeQueryResult = results[0];
			Assert.isNull(result.error);
			Assert.isNotNull(result);
			Assert.isNotNull(result.data);
			Assert.equals(3, result.data.length);

			// Faulty DROP result
			result = results[1];
			Assert.isNotNull(result.error);
			Assert.isType(result.error, SQLError);

			// UPDATE result
			result = results[2];
			Assert.isNull(result.error);
			Assert.isNotNull(result);
			Assert.equals(1, result.rowsAffected);

			// Second SELECT result
			result = results[3];
			Assert.isNull(result.error);
			Assert.isNotNull(result);
			Assert.isNotNull(result.data);
			Assert.equals(1, result.data.length);

			testMultiQueryFailOnError();
		}


		private function testMultiQueryFailOnError():void
		{
			var query:BreezeRawQuery = new BreezeRawQuery(_db);
			query.multiQueryFailOnError([
				"SELECT id, title FROM " + _tableName,
				"DROP TABLEz " + _tableName, // forced error
				"UPDATE " + _tableName + " SET title = :title WHERE id = :id" // should not be executed
			], [null, null, { title: "Mountains", id: 1 }], onMultiQueryFailOnErrorCompleted);
		}


		private function onMultiQueryFailOnErrorCompleted(error:Error, results:Vector.<BreezeQueryResult>):void
		{
			Assert.isNotNull(error);
			Assert.isNotNull(results);
			Assert.equals(2, results.length);

			// First SELECT result
			var result:BreezeQueryResult = results[0];
			Assert.isNull(result.error);
			Assert.isNotNull(result);
			Assert.isNotNull(result.data);
			Assert.equals(3, result.data.length);

			// Faulty DROP result
			result = results[1];
			Assert.isNotNull(result.error);
			Assert.isType(result.error, SQLError);

			testMultiQueryTransaction();
		}


		private function testMultiQueryTransaction():void
		{
			var query:BreezeRawQuery = new BreezeRawQuery(_db);
			query.multiQueryTransaction([
				"UPDATE " + _tableName + " SET title = :title WHERE id = :id",
				"DROP TABLEz " + _tableName, // forced error
				"SELECT id, title FROM " + _tableName // should not be executed
			], [{ title: "Mountains", id: 1}], onMultiQueryTransactionCompleted);
		}


		private function onMultiQueryTransactionCompleted(error:Error, results:Vector.<BreezeQueryResult>):void
		{
			Assert.isNotNull(error);
			Assert.isNotNull(results);
			Assert.equals(2, results.length);

			// Check that the UPDATE has been rolled back
			var query:BreezeRawQuery = new BreezeRawQuery(_db);
			query.select("SELECT id, title FROM " + _tableName + " WHERE id = :id", { id: 1 }, onCheckMultiQueryTransactionCompleted);
		}


		private function onCheckMultiQueryTransactionCompleted(error:Error, results:Collection):void
		{
			Assert.isNull(error);
			Assert.isNotNull(results);
			Assert.equals(1, results.length);
			Assert.equals(1, results[0].id);
			Assert.equals("Hills", results[0].title);

			currentAsync.complete();
		}


		public function tearDownClass():void
		{
			if(_db != null && _db.file != null)
			{
				_db.file.deleteFile();
			}
		}
		
	}
	
}
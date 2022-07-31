#Include <Yunit\Yunit>
#Include <Yunit\Window>
#Include <SQLite\SQLite3>

Yunit.Use(YunitWindow).Test(SQLiteTests)

class SQLiteTests {
	class PublicAPI {
		test1_open() {
			sql := SQLite3()
			res := sql.Open("..\examples\example.db")
			Yunit.Assert(res = SQLITE_OK && IsNumber(sql.hDatabase))
		}
		test2_close() {
			sql := SQLite3()
			sql.Open("..\examples\example.db")
			Yunit.Assert(sql.Close() = SQLITE_OK && !IsNumber(sql.hDatabase))
		}
		test3_createTable(){
			sql := SQLite3()
			sql.Open("..\examples\example.db")

			tests := Array(
				(Ltrim
					"CREATE TABLE IF NOT EXISTS person (
					id        INTEGER PRIMARY KEY ASC AUTOINCREMENT
							UNIQUE
							NOT NULL,
					name      STRING,
					last_name STRING,
					age       INTEGER,
					height    STRING,
					weight    INTEGER
					`);"
				),
				"INSERT INTO person ('name','last_name') VALUES('Isaias','Baez')",
				"SELECT id,name FROM person WHERE TRUE",
				"DROP TABLE IF EXISTS person"
			)

			for statement in tests
			{
				try sql.Exec(statement)
				catch
					OutputDebug(SQLite3.errMsg), Yunit.Assert(false)
			}
			sql.Close()
		}
	}

	class StaticMethods {
		test1_escape() {
			tests := Array(
				"one's type",
				"leo's",
				"his cars' info"
			)

			for str in tests
			{
				eStr := SQLite3.Escape(str)
				Yunit.Assert(eStr == RegExReplace(str, "'", "''"), str "->" eStr)
			}
		}
		test2_reportResult() {
			tests := Array(
				SQLITE_INTERNAL,
				SQLITE_PERM,
				SQLITE_ABORT,
				SQLITE_BUSY,
				SQLITE_LOCKED
			)

			for errStr in tests
				Yunit.Assert(SQLite3.ReportResult(errStr) = errStr)

			tests := Array(
				"Internal logic error in SQLite",
				"Access permission denied",
				"Callback routine requested an abort",
				"The database file is locked",
				"A table in the database is locked"
			)

			for errStr in tests
			{
				errBuffer := Buffer(StrPut(errStr, "UTF-8"))
				StrPut(errStr, errBuffer, "UTF-8")

				try SQLite3.ReportResult(A_Index, errBuffer)
				catch
				{
					Yunit.Assert(SQLite3.errCode = A_Index)
					Yunit.Assert(SQLite3.errMsg == errStr)
				}
			}
		}
	}

	class Table {
		sql := SQLite3("A:/Scripts to Work on/CompanyInfo/Crazy Business File.db")
		
		test1_tableInfo() {
			sql := this.sql

			try table := sql.Exec("SELECT UserNames,Domain FROM DATA WHERE country='denmark'")
			catch
				OutputDebug(SQLite3.errCode " " SQLite3.errMsg), Yunit.Assert(false)

			tests := Array(
				{value:table.nRows, expected:29221},
				{value:table.rows.Length, expected:table.nRows},
				{value:table.headers[1], expected:"UserNames"},
				{value:table.header["Domain"], expected:2},
				{value:Type(table.row[5]), expected:"Array"}
			)
			
			for test in tests
				Yunit.Assert(test.value = test.expected)
		}

		test2_getHeaderIndex() {
			sql := this.sql

			try table := sql.Exec("SELECT UserNames,Domain FROM DATA WHERE country='denmark'")
			catch
				OutputDebug(SQLite3.errCode " " SQLite3.errMsg), Yunit.Assert(false)

			index := SQLite3.Table.GetHeaderIndex(table, "Domain")
			Yunit.Assert(index = 2)
		}
	}
}
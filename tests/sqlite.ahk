#Include <Yunit\Yunit>
#Include <Yunit\Window>
#Include <SQLite\SQLite3>

Yunit.Use(YunitWindow).Test(SQLiteTests)

class SQLiteTests
{
	test1_open() {
		sql := SQLite3()
		res := sql.Open("..\examples\example.db")
		Yunit.Assert(res == SQLITE_OK && IsNumber(sql.hDatabase))
	}
	test2_close() {
		sql := SQLite3()
		res := sql.Open("..\examples\example.db")
		res := sql.Close()
		Yunit.Assert(res == SQLITE_OK && !IsNumber(sql.hDatabase))
	}
	test3_escape() {
		for str in ["one's type", "leo's", "his cars' info"]
		{
			eStr := SQLite3.Escape(str)
			Yunit.Assert(eStr == RegExReplace(str, "'", "''"), str "->" eStr)	
		}
	}
}
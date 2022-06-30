#Include <Yunit\Yunit>
#Include <Yunit\Window>
#Include <SQLite\SQLite3>

Yunit.Use(YunitWindow).Test(SQLiteTests)

class SQLiteTests
{
	sql := SQLite3()

	test3_escape() {
		for str in ["one's type", "leo's", "his cars' info"]
		{
			eStr := SQLite3.Escape(str)
			Yunit.Assert(eStr == RegExReplace(str, "'", "''"), str "->" eStr)	
		}
	}
}
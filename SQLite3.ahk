#Requires Autohotkey v2.0-
#Include .\lib\SQLite3.h.ahk

class IBase {
	/**
	 * Used to manage automatic loading of a database file when
	 * instatiating the class by passing the `dbFile` parameter
	 * with a path to a valid SQlite database file.
	 *
	 * [Documentation](https://lexikos.github.io/v2/docs/Objects.htm#Custom_NewDelete)
	 *
	 * ---
	 * ### Params:
	 * - `dbFile [optional]`    - Path to the database file to be opened
	 * - `overwrite [optional]` - delete the existing db file if exists
	 *
	 * ### Returns:
	 * - `NONE`
	 *
	 */
	__New(dbFile?, overwrite:=false) {
		dllBin := A_LineFile '\..\bin\' SQLite3.bin
		if !this.ptr := DllCall('LoadLibrary', 'str', dllBin)
			throw OSError(A_LastError, A_ThisFunc, 'Could not load `n' StrReplace(dllBin, A_ScriptDir, "%A_ScriptDir%"))

		if IsSet(dbFile)
			this.Open(dbFile, overwrite)
	}

	/**
	 * Used to manage functions that haven't been defined yet.
	 *
	 * By default this meta function will throw an error for all non defined
	 * methods. This can be overridden by setting the `this.dllManualMode` option to `true`.
	 *
	 * Must be used with care as you will have to understand the underlying
	 * DllCall that will be made.
	 *
	 * When manual mode is enabled you will call your method normally but each
	 * parameter must be acompanied by its type, exactly as DllCall would expect.
	 *
	 * [Documentation](https://lexikos.github.io/v2/docs/Objects.htm#Meta_Functions)
	 *
	 * ---
	 * ### Params:
	 * - `Name`   - The name of the method without the sqlite3_ prefix.
	 * - `Params` - DllCall style parameters
	 *
	 * ### Returns:
	 * - `Library Defined` - For mor information see each function's documentation
	 * ---
	 * ### Examples:
	 * Use the slqite3_get_table function directly as defined in the original library
	 * ```
	 sql := sqlite3('data.db')
	 sql.dllManualMode := true
	 sql.get_table("ptr" , sql.hDatabase
	              ,"ptr" , sqlStatement
	              ,"ptr*", &pResult:=0
	              ,"ptr*", &nRows:=0
	              ,"ptr*", &nCols:=0
	              ,"ptr*", &pErrMsg:=0, "cdecl")
	 * ```
	 *
	 */
	__Call(Name, Params) {
		if !this.dllManualMode
			throw MemberError(Name " is not implemented yet", A_ThisFunc)

		res := DllCall(fname:=SQLite3.bin "\sqlite3_" Name, Params*)
		return SQLite3.ReportResult(this, res)
	}

	/**
	 * When an object is destroyed, __Delete is called.
	 *
	 * Used to clean up after the object is no longer in use.
	 *
	 * [Documentation](https://lexikos.github.io/v2/docs/Objects.htm#Custom_NewDelete)
	 *
	 *---
	 * ### Params:
	 * - `NONE`
	 *
	 * ### Returns:
	 * - `NONE`
	 *
	 */
	__Delete() => DllCall("FreeLibrary", "ptr", this.ptr)
}

/**
 * Sqlite 3 Interface object that makes it easy to work with sqlite databases in Autohotkey v2.
 *
 * ---
 * ### Properties:
 * - `ptr`            - Copy of the current database pointer
 * - `errCode`        - Error code returned by the library (if any ) after last operation
 * - `errMsg`         - Error message returned by the library (if any ) after last operation
 * - `autoEscape`     - Option to automatically escape all strings passed to the library.
 *                      Enabled by default
 * - `dllManualMode`  - Option to call library functions that havent been defined by the
 *                      class yet. Disabled by default.
 *
 * ### Methods:
 * - `Open`     - Opens a database
 * - `Close`    - Closes a database 
 * - `Exec`     - Executes an arbitrary SQL Statement that conforms to the sqlite3 engine
 *
 * ### Implemented functions:
 * - `GetTable`
 *
 */
Class SQLite3 extends IBase {
	static bin     := "sqlite3" (A_PtrSize = 4 ? 32 : 64) ".dll"

	ptr            := 0
	errCode        := 0
	errMsg         := ""
	hDatabase      := Buffer(A_PtrSize)

	_autoEscape    := true
	autoEscape {
		get => this._autoEscape
		set {
			switch Value {
			case true,false:
				return this._autoEscape := Value
			default:
				throw ValueError("This property only accepts true or false"
				                ,A_ThisFunc, "autoEscape:" Value)
			}
		}
	}
	_dllManualMode := false
	dllManualMode {
		get => this._dllManualMode
		set {
			switch Value {
			case true,false:
				return this._dllManualMode := Value
			default:
				throw ValueError("This property only accepts true or false"
				                ,A_ThisFunc, "dllManualMode: " Value)
			}
		}
	}

	/**
	 * Opens an SQLite database file as specified by the filename argument.
	 *
	 * The filename argument is interpreted as UTF-8.
	 *
	 * A database connection handle is usually returned in `this.hDatabase`,
	 * even if an error occurs. The only exception is that if SQLite is unable
	 * to allocate memory to hold the SQLite3 object, a `NULL` will be written
	 * into `this.hDatabase` instead of a pointer to the SQLite3 object.
	 *
	 * If the database is opened (and/or created) successfully,
	 * then `SQLITE_OK` is returned. Otherwise an error code is returned and the
	 * error description saved in `this.errMsg`.
	 *
	 * [Documentation](https://www.sqlite.org/c3ref/open.html)
	 *
	 * ---
	 * ### Params:
	 * - `path`       - database file location
	 * - `overwrite`  - delete the existing db file if exists
	 *
	 * ### Returns:
	 *
	 * - `SQLITE_OK`     - Operation was successful
	 * - `SQLITE_ERROR+` - Error code in this.errCode and
	 *                     error description in this.errMsg
	 *
	 */
	Open(path, overwrite:=false) {
		this.errCode := 0
		this.errMsg  := ""

		StrPut(path
		      ,pathBuffer:=Buffer(StrPut(path,"UTF-8"))
		      ,"UTF-8")

		if overwrite
			try FileDelete path

		res := DllCall(SQLite3.bin "\sqlite3_open"
		              ,"ptr", pathBuffer
		              ,"ptr", this.hDatabase, "cdecl")

		if !this.hDatabase := NumGet(this.hDatabase, "ptr")
		{
			StrPut(errStr:="Database could not be opened"
			      ,errBuffer:=Buffer(StrPut(errStr, "UTF-8"))
			      ,"UTF-8")
		}

		return SQLite3.ReportResult(this, res, errBuffer ?? unset)
	}

	/**
	 * Destroys an SQLite3 object.
	 *
	 * Ideally, applications should finalize all prepared statements,
	 * close all BLOB handles, and finish all sqlite3_backup objects
	 * associated with the SQLite3 object prior to attempting to close the object.
	 *
	 * [Documentation](https://www.sqlite.org/c3ref/close.html)
	 *
	 * ---
	 * ### Params:
	 * - `NONE`
	 *
	 * ### Returns:
	 * - `SQLITE_OK`   - Object is successfully destroyed and
	 *                   all associated resources are deallocated.
	 * - `SQLITE_BUSY` - Object is associated with unfinalized prepared
	 *                   statements, BLOB handlers, and/or
	 *                   unfinished sqlite3_backup objects.
	 *
	 */
	Close() {
		this.errCode := 0
		this.errMsg  := ""
		res := DllCall(SQLite3.bin "\sqlite3_close"
		              ,"ptr", this.hDatabase, "cdecl")

		this.hDatabase := Buffer(A_PtrSize)
		return SQLite3.ReportResult(this, res)
	}

	/**
	 * This interface is a convenience wrapper around
	 * `sqlite3_prepare_v2()`, `sqlite3_step()`, and `sqlite3_finalize()`,
	 * that allows an application to run multiple statements of SQL without
	 * having to use a lot of code.
	 *
	 * It runs zero or more UTF-8 encoded, semicolon-separate SQL statements
	 * passed into its 2nd argument, in the context of the current database connection.
	 *
	 * [Documentation](https://www.sqlite.org/c3ref/exec.html)
	 *
	 * ---
	 * ### Params:
	 * - `sql`          - SQL Statement to be executed
	 *
	 * ### Returns:
	 * - `SQLITE_OK`    - Statement was executed correctly
	 * - `SQLITE_ABORT` - Callback function returned non zero value (not implemented)
	 *
	 * ### Notes:
	 * Any error message written by `sqlite3_exec()` into memory will be reported
	 * via `this.errMsg` and `this.errCode` and an exeption will be thrown.
	 *
	 * This allows for try statements like this:
	 *
	 * ```
	try sql.exec(sqlStatement)
	catch
		OutputDebug this.errMsg
	 * ```
	 */
	Exec(sql, callback:="") {
		if !IsNumber(this.hDatabase)
			throw MemberError( "Not connected to a database`n"
			                 . "Set the path to a database when creating the object or "
			                 . "use the Open method to connect to a database."
			                 , A_ThisFunc
			                 , "hDatabase")

		StrPut(sql
		      ,sqlStatement:=Buffer(StrPut(sql, "UTF-8"))
		      ,"UTF-8")

		if sql ~= "i)SELECT"
			return SQLite3.GetTable(this, sqlStatement)
		else
		{

			ObjAddRef(ObjPtr(this))
			thisObjAddr := ObjPtrAddRef(this)

			res := DllCall(SQLite3.bin "\sqlite3_exec"
			              ,"ptr" , this.hDatabase
			              ,"ptr" , sqlStatement
			              ,"ptr" , callback ? CallbackCreate(callback, "F C",4) : 0
			              ,"ptr" , thisObjAddr
			              ,"ptr*", &pErrMsg:=0, "cdecl")

			ObjRelease(thisObjAddr)
			return SQLite3.ReportResult(this, res, pErrMsg)
		}
	}

	/**
	 * This is a legacy interface. The Use of this interface is not recommended.
	 *
	 * Definition: A result table is memory data structure created by the `sqlite3_get_table()` interface.
	 * A result table records the complete query results from one or more queries.
	 *
	 * This method return a <Sqlite3.Table> object.
	 *
	 * [Documentation](https://www.sqlite.org/c3ref/free_table.html)
	 *
	 * ---
	 * ### Params:
	 * - `sql` - SQLITE statement that returns a table
	 *
	 * ### Returns:
	 * - `Sqlite3.Table` object - For more information check the <Sqlite3.Table> information.
	 *
	 */
	GetTable(sql) {
		StrPut(sql
		      ,sqlStatement:=Buffer(StrPut(sql, "UTF-8"))
		      ,"UTF-8")

		return SQLite3.GetTable(this, sqlStatement)
	}

;private methods
;---------------------

	/**
	 * This function escapes all single quotes from SQL strings.
	 *
	 * ### Params:
	 * - `str` - String to be escaped
	 *
	 * ### Returns:
	 * - `str` - Escaped string
	 */
	static Escape(str, autoTrim:=true)
	{
		str := StrReplace(str, "`t", "→")
		str := StrReplace(str, "`n", "¶")
		return StrReplace(autoTrim ? Trim(str) : str, "'", "''")
	}

	static Restore(str)
	{
		str := StrReplace(str, "→", "`t")
		str := StrReplace(str, "¶", "`n")
		return StrReplace(str, "''", "'")
	}

	static ReportResult(obj, res, msgBuffer:=unset) {
		static PREV_FUNC := -2
		if res = SQLITE_OK || res && !IsSet(msgBuffer)
			return res

		obj.errCode := res
		obj.errMsg  := StrGet(msgBuffer, "UTF-8")
		throw Error(obj.errMsg, PREV_FUNC, obj.errCode)
	}

	static GetTable(obj, sqlBuffer) {
		obj.errCode := 0
		obj.errMsg  := ""

		res := DllCall(SQLite3.bin "\sqlite3_get_table"
		              ,"ptr" , obj.hDatabase
		              ,"ptr" , sqlBuffer
		              ,"ptr*", &pResult:=0
		              ,"ptr*", &nRows:=0
		              ,"ptr*", &nCols:=0
		              ,"ptr*", &pErrMsg:=0, "cdecl")

		SQLite3.ReportResult(obj, res, pErrMsg)

		table := SQLite3.Table(pResult, nRows, nCols)

		res := DllCall(SQLite3.bin "\sqlite3_free_table"
		              ,"ptr", pResult)

		SQLite3.ReportResult(obj, res)

		return table
	}

	/**
	* Implements a simple table structure used to access data returned
	* by any SQL statement that returns rows of data.
	*
	* [Docuemnentation](https://www.sqlite.org/c3ref/free_table.html)
	*
	* ---
	* ### Properties:
	* - `nRows`          - Number of rows in the table
	* - `nCols`          - Number of columns in the table
	* - `headers`        - An array that contains the headers of the returned table
	* - `header[value]`  - Returns either the header name or header index based on the value passed
	*	- `value` - Integer / String
	*		  - If an integer is passed, the name of the header is returned
	*		  - If a string is passed, the index of the header is returned
	* - `rows`           - An array that contains a list of `rows` that are arrays of each field.
	*                      The length of the `row` array will be the same as the number of columns.
	* - `row[n]`         - Returns an array that represents the `row` passed as n.
	*                      The length of the `row` array will be the same as the number of columns.
	* - `fields`         - An array of each field in the table result returned by SQlite.
	*                      This property can be used to loop through the entire table quickly.
	* - `field[row,col]` - Returns a specific field by specifying a row and column.
	*	- `row` - Integer
	*	- `col` - Integer / String
	*
	* - `cell[row,col]`  - A sysnonym for <field>.
	*                      Returns a specific cell by specifying a row and column.
	*	- `row` - Integer
	*	- `col` - Integer / String
	*
	* - `data`           - An array that represents the full table.
	*                      The first index contains the same information as SQLite3.Table.headers.
	*                      The second index contains the same information as SQLite3.Table.rows.
	*
	*/
	class Table {
		nRows   := 0
		nCols   := 0

		headers := Array()
		header[value] {
			get {
				switch Type(value) {
					case "Integer":
						return this.headers[value]
					case "String":
						return SQLite3.Table.GetHeaderIndex(this, value)
					default:
						throw ValueError( "Invalid value type.`n"
						                . "Expected: integer or string values."
						                , A_ThisFunc
						                , Type(value))
				}
			}
		}

		rows := Array()
		row[n] => this.rows[n]

		fields := Array()
		cell[row,col] => this.field[row, col]
		field[row,col] {
			get {
				if Type(row) != "Integer"
				|| !(Type(col) ~= "i)Integer|String")
					throw ValueError( "Invalid value type.`n"
					                . "Row must be an Integer`n"
					                . "Col Must be an integer or string."
					                , A_ThisFunc
					                , "Row: " Type(row) "`nCol: " Type(col))

				if row > this.nRows || row < 1
				|| col > this.nCols || col < 1
					throw ValueError( "Invalid range."
					                , A_ThisFunc
					                , "The value must be between 0 and the max row/col.")

				if Type(col) = "String"
					col := this.header[col]

				return this.rows[row][col]
			}
		}

		data => Array(this.headers, this.rows)

		__New(tblPointer, nRows, nCols) {
			this.nCols := nCols
			this.nRows := nRows

			OffSet := 0 - A_PtrSize
			loop (nRows+1) * nCols
			{
				; We need to handle NULL data
				if !nxtPtr:=NumGet(tblPointer, OffSet += A_PtrSize, "ptr")
					data := ""
				else
					data := StrGet(nxtPtr, "UTF-8")

				if A_Index <= nCols
					this.headers.Push(data)
				else
				{
					tempData .= data '■'
					this.fields.Push(data)

					if !Mod(A_Index, nCols)
					{
						tempData := RegExReplace(tempData, '■$')
						this.rows.Push(StrSplit(tempData, '■'))
						tempData := ""
					}
				}
			}
		}

		static GetHeaderIndex(table, str) {
			for header in table.headers
				if str = header
					return A_Index
		}
	}
}
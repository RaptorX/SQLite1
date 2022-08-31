#Requires Autohotkey v2.0-
#Include .\lib\SQLite3.h.ahk

class SQliteBase {
	/**
	 * Function: __New(dbFile:=unset)
	 * https://lexikos.github.io/v2/docs/Objects.htm#Custom_NewDelete
	 *
	 * Used to manage automatic loading of a database file when
	 * instatiating the class by passing the `dbFile` parameter
	 * with a path to a valid SQlite database file.
	 *
	 * Params:
	 * dbFile [optional] - Path to the database file to be opened
	 *
	 * Returns: NONE
	 */
	__New(dbFile:=unset) {
		dllBin := A_LineFile "\..\bin\" SQLite3.bin
		if !this.ptr := DllCall("LoadLibrary", "str", dllBin)
			throw OSError(A_LastError, "Could not load " dllBin, A_ThisFunc)

		if IsSet(dbFile)
			this.Open(dbFile)
	}

	/**
	 * Function: __Call(Name, Params)
	 * https://lexikos.github.io/v2/docs/Objects.htm#Meta_Functions
	 *
	 * Used to manage functions that havent been defined yet.
	 * By default this meta function will throw an error for all non defined
	 * methods.
	 *
	 * This can be overridden by setting the `this.dllManualMode` option to `true`.
	 *
	 * Must be used with care as you will have to understand the underlying
	 * DllCall that will be made.
	 *
	 * When manual mode is enabled you will call your method normally but each
	 * parameter must be acompanied by its type, exactly as DllCall would expect.
	 *
	 * --- ahk
	 * sqlite3.get_table("ptr" , sqlite3.hDatabase
	 *                  ,"ptr" , sqlStatement
	 *                  ,"ptr*", &pResult:=0
	 *                  ,"ptr*", &nRows:=0
	 *                  ,"ptr*", &nCols:=0
	 *                  ,"ptr*", &pErrMsg:=0, "cdecl")
	 * ---
	 * 
	 * Params:
	 * Name   - The name of the method without the sqlite3_ prefix.
	 * Params - An Array of parameters. This includes only the parameters between () or [], so may be empty.
	 *
	 * Returns: USER DEFINED
	 */
	__Call(Name, Params) {
		if !this.dllManualMode
			throw MemberError(Name " is not implemented yet", A_ThisFunc)
		
		res := DllCall(fname:=SQLite3.bin "\sqlite3_" Name, Params*)
		return SQLite3.ReportResult(this, res)
	}

	/**
	 * Function: __Delete()
	 * https://lexikos.github.io/v2/docs/Objects.htm#Custom_NewDelete
	 *
	 * When an object is destroyed, __Delete is called.
	 * Used to clean up after the object is no longer in use.
	 *
	 * Params: NONE
	 * Returns: NONE
	 */
	__Delete() {
		DllCall("FreeLibrary", "ptr", this.ptr)
	}
}

Class SQLite3 extends SQliteBase {

;private vars
;---------------------

	static bin     := "sqlite3" (A_PtrSize = 4 ? 32 : 64) ".dll"

;public vars
;---------------------

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

;public methods
;---------------------

	/**
	 * Function: Open(path)
	 * https://www.sqlite.org/c3ref/open.html
	 *
	 * Opens an SQLite database file as specified by the filename argument.
	 * The filename argument is interpreted as UTF-8.
	 *
	 * A database connection handle is usually returned in `this.hDatabase`,
	 * even if an error occurs. The only exception is that if SQLite is unable
	 * to allocate memory to hold the SQLite3 object, a NULL will be written
	 * into `this.hDatabase` instead of a pointer to the SQLite3 object.
	 *
	 * If the database is opened (and/or created) successfully,
	 * then SQLITE_OK is returned. Otherwise an error code is returned and the
	 * error description saved in this.errMsg.
	 *
	 * Params:
	 * path       - database file location
	 *
	 * Returns:
	 *
	 * SQLITE_OK     - Operation was successful
	 * SQLITE_ERROR+ - Error code in this.errCode and
	 *                 error description in this.errMsg
	 */
	Open(path) {
		this.errCode := 0
		this.errMsg  := ""

		StrPut(path
		      ,pathBuffer:=Buffer(StrPut(path,"UTF-8"))
		      ,"UTF-8")

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
	 * Function: Close()
	 * https://www.sqlite.org/c3ref/close.html
	 *
	 * Destroys an SQLite3 object.
	 *
	 * Ideally, applications should finalize all prepared statements,
	 * close all BLOB handles, and finish all sqlite3_backup objects
	 * associated with the SQLite3 object prior to attempting to close the object.
	 *
	 * Params: NONE
	 *
	 * Returns:
	 * SQLITE_OK   - Object is successfully destroyed and
	 *               all associated resources are deallocated.
	 * SQLITE_BUSY - Object is associated with unfinalized prepared
	 *               statements, BLOB handlers, and/or
	 *               unfinished sqlite3_backup objects.
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
	 * Function: Exec(sql)
	 * https://www.sqlite.org/c3ref/exec.html
	 *
	 * This interface is a convenience wrapper around
	 * sqlite3_prepare_v2(), sqlite3_step(), and sqlite3_finalize(),
	 * that allows an application to run multiple statements of SQL without
	 * having to use a lot of code.
	 *
	 * It runs zero or more UTF-8 encoded, semicolon-separate SQL statements
	 * passed into its 2nd argument, in the context of the current database connection.
	 *
	 * Params:
	 * sql          - SQL Statement to be executed
	 *
	 * Returns:
	 * SQLITE_OK    - Statement was executed correctly
	 * SQLITE_ABORT - Callback function returned non zero value (not implemented)
	 *
	 * Notes:
	 * Any error message written by sqlite3_exec() into memory will be reported
	 * via this.errMsg and this.errCode and an exeption will be thrown.
	 *
	 * This allows for try statements like this:
	 *
	 * --- ahk ---
	 * try sql.exec(sqlStatement)
	 * catch
	 * 	OutputDebug this.errMsg
	 * ---
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

		if sql ~= "i)SELECT|PRAGMA"
		{
			res := DllCall(SQLite3.bin "\sqlite3_get_table"
			              ,"ptr" , this.hDatabase
			              ,"ptr" , sqlStatement
			              ,"ptr*", &pResult:=0
			              ,"ptr*", &nRows:=0
			              ,"ptr*", &nCols:=0
			              ,"ptr*", &pErrMsg:=0, "cdecl")

			SQLite3.ReportResult(res, pErrMsg)

			table := SQLite3.Table(pResult, nRows, nCols)

			res := DllCall(SQLite3.bin "\sqlite3_free_table"
			              ,"ptr", pResult)

			SQLite3.ReportResult(res)

			return table
		}
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

;private methods
;---------------------

	/**
	 * Function: Escape(str)
	 *
	 * This function escapes all single quotes from SQL strings.
	 *
	 * Params:
	 * str - String to be escaped
	 *
	 * Returns:
	 * str - Escaped string
	 */
	static Escape(str) => StrReplace(str, "'", "''")

	static ReportResult(obj, res, msgBuffer:=unset) {
		static PREV_FUNC := -2
		if res = SQLITE_OK || res && !IsSet(msgBuffer)
			return res

		obj.errCode := res
		obj.errMsg  := StrGet(msgBuffer, "UTF-8")
		throw Error(obj.errMsg, PREV_FUNC, obj.errCode)
	}
	
	static GetTable(obj, sql) {
	}

;sub classes
;---------------------
	/**
	* Class: Table
	* https://www.sqlite.org/c3ref/free_table.html
	*
	* Implements a simple table structure used to access data returned
	* by any SQL statement that returns rows of data.
	*
	* Property: nRows
	* Number of rows in the table
	* 
	* Property: nCols
	* Number of columns in the table
	* 
	* Property: headers
	* An array that contains the headers of the returned table
	*
	* Property: header[value]
	* Returns either the header name or header index based on the value passed
	*
	* value - Integer / String
	*
	*         If an integer is passed, the name of the header is returned
	*
	*         If a string is passed, the index of the header is returned
	*
	* Property: rows
	* An array that contains a list of `rows` that are arrays of each field.
	* The length of the `row` array will be the same as the number of columns.
	*
	* Property: row[n]
	* Returns an array that represents the `row` passed as n.
	* The length of the `row` array will be the same as the number of columns.
	* 
	* Property: fields
	* An array of each field in the table result returned by SQlite.
	*
	* This property can be used to loop through the entire table quickly.
	*
	* Property: field[row,col]
	* Returns a specific field by specifying a row and column.
	*
	* row - Integer
	* col - Integer / String
	*
	* Property: cell[row,col]
	* A sysnonym for <field>
	* Returns a specific cell by specifying a row and column.
	*
	* row - Integer
	* col - Integer / String
	*
	* Property: data
	* An array that represents the full table.
	* The first index contains the same information as SQLite3.Table.headers.
	* The second index contains the same information as SQLite3.Table.rows.
	*
	* Static Method: GetHeaderIndex
	* Returns the index of a string that refers to a specific header in a table.
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
					tempData .= data A_Tab
					this.fields.Push(data)

					if !Mod(A_Index, nCols)
					{
						this.rows.Push(StrSplit(Trim(tempData), A_Tab))
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
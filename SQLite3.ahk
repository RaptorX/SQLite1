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

	static bin            := "sqlite3" (A_PtrSize = 4 ? 32 : 64) ".dll"

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
			static errMsg := "This property only accepts true or false"
			if !(value ~= true "|" false)
				throw ValueError(errMsg, -1, A_ThisFunc "> autoEscape")
			else
				return this._autoEscape := value
		}
	}
	_dllManualMode := false
	dllManualMode {
		get => this._dllManualMode
		set {
			static errMsg := "This property only accepts true or false"
			if !(value ~= true "|" false)
				throw ValueError(errMsg, -1, A_ThisFunc "> dllManualMode")
			else
				return this._dllManualMode := value
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
	 * error description saved in SQLite3.error.
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
			errBuffer := Buffer(StrPut(errStr:="Database could not be opened", "UTF-8"))
			StrPut(errStr, errBuffer, "UTF-8")
		}

		return SQLite3.ReportResult(res, errBuffer ?? unset)
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
		return SQLite3.ReportResult(res)
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

		StrPut(sql,sqlStatement := Buffer(StrPut(sql, "UTF-8")),"UTF-8")

		ObjAddRef(ObjPtr(this))
		thisObjAddr := ObjPtrAddRef(this)

		res := DllCall(SQLite3.bin "\sqlite3_exec"
		              ,"ptr" , this.hDatabase
		              ,"ptr" , sqlStatement
		              ,"ptr" , callback ? CallbackCreate(callback, "F C",4) : 0
		              ,"ptr" , thisObjAddr
		              ,"ptr*", &pErrMsg:=0, "cdecl")

		ObjRelease(thisObjAddr)
		return SQLite3.ReportResult(res, pErrMsg)
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

	static ReportResult(res, msgBuffer:=unset) {
		static PREV_FUNC := -2
		if res = SQLITE_OK || res && !IsSet(msgBuffer)
			return res

		this.errCode := res
		this.errMsg  := StrGet(msgBuffer, "UTF-8")
		throw Error(this.errMsg, PREV_FUNC, this.errCode)
	}

;sub classes
;---------------------
}
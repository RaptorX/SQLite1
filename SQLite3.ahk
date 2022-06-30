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
		if !SQLite3.ptr := DllCall("LoadLibrary", "str", dllBin)
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
		DllCall("FreeLibrary", "ptr", SQLite3.ptr)
	}
}

Class SQLite3 extends SQliteBase {

;private vars
;---------------------

	static ptr            := 0
	static bin            := "sqlite3" (A_PtrSize = 4 ? 32 : 64) ".dll"
	

;public vars
;---------------------

	hDatabase := Buffer(A_PtrSize)
	
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

}
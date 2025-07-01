/*
 * pqStubInit.c --
 *
 *	Stubs tables for the foreign PostgreSQL libraries so that
 *	Tcl extensions can use them without the linker's knowing about them.
 *
 * @CREATED@ 2011-04-12 02:23:01Z by genExtStubs.tcl from ../generic/pqStubDefs.txt
 *
 * Copyright (c) 2010 by Kevin B. Kenny.
 *
 * Please refer to the file, 'license.terms' for the conditions on
 * redistribution of this file and for a DISCLAIMER OF ALL WARRANTIES.
 *
 *-----------------------------------------------------------------------------
 */

#include <tcl.h>
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif
#include "fakepq.h"

/*
 * Static data used in this file
 */

/*
 * ABI version numbers of the PostgreSQL API that we can cope with.
 */

static const char *const pqSuffixes[] = {
    "", ".5", NULL
};

/*
 * Names of the libraries that might contain the PostgreSQL API
 */

static const char *const pqStubLibNames[] = {
    /* @LIBNAMES@: DO NOT EDIT THESE NAMES */
    "libpq", NULL
    /* @END@ */
};

/*
 * Names of the functions that we need from PostgreSQL
 */

static const char *const pqSymbolNames[] = {
    /* @SYMNAMES@: DO NOT EDIT THESE NAMES */
    "pg_encoding_to_char",
    "PQclear",
    "PQclientEncoding",
    "PQcmdTuples",
    "PQconnectdb",
    "PQerrorMessage",
    "PQdescribePrepared",
    "PQexec",
    "PQexecPrepared",
    "PQdb",
    "PQfinish",
    "PQfname",
    "PQfnumber",
    "PQftype",
    "PQgetisnull",
    "PQgetlength",
    "PQgetvalue",
    "PQhost",
    "PQnfields",
    "PQnparams",
    "PQntuples",
    "PQoptions",
    "PQparamtype",
    "PQpass",
    "PQport",
    "PQprepare",
    "PQresultErrorField",
    "PQresultStatus",
    "PQsetClientEncoding",
    "PQsetNoticeProcessor",
    "PQstatus",
    "PQuser",
    "PQtty",
    NULL
    /* @END@ */
};

/*
 * Table containing pointers to the functions named above.
 */

static pqStubDefs pqStubsTable;
pqStubDefs* pqStubs = &pqStubsTable;

/*
 *-----------------------------------------------------------------------------
 *
 * PQInitStubs --
 *
 *	Initialize the Stubs table for the PostgreSQL API
 *
 * Results:
 *	Returns the handle to the loaded PostgreSQL client library, or NULL
 *	if the load is unsuccessful. Leaves an error message in the
 *	interpreter.
 *
 *-----------------------------------------------------------------------------
 */

MODULE_SCOPE Tcl_LoadHandle
PostgresqlInitStubs(Tcl_Interp* interp)
{
    int i, j;
    int status;			/* Status of Tcl library calls */
    Tcl_Obj* path;		/* Path name of a module to be loaded */
    Tcl_Obj* shlibext;		/* Extension to use for load modules */
    Tcl_LoadHandle handle = NULL;
				/* Handle to a load module */

    /* Determine the shared library extension */

    status = Tcl_EvalEx(interp, "::info sharedlibextension", -1,
			TCL_EVAL_GLOBAL);
    if (status != TCL_OK) return NULL;
    shlibext = Tcl_GetObjResult(interp);
    Tcl_IncrRefCount(shlibext);

    /* Walk the list of possible library names to find an PostgreSQL client */

    status = TCL_ERROR;
    for (i = 0; status == TCL_ERROR && pqStubLibNames[i] != NULL; ++i) {
	for (j = 0; status == TCL_ERROR && pqSuffixes[j] != NULL; ++j) {
	    path = Tcl_NewStringObj(pqStubLibNames[i], -1);
	    Tcl_AppendObjToObj(path, shlibext);
	    Tcl_AppendToObj(path, pqSuffixes[j], -1);
	    Tcl_IncrRefCount(path);

	    /* Try to load a client library and resolve symbols within it. */

	    Tcl_ResetResult(interp);
	    status = Tcl_LoadFile(interp, path, pqSymbolNames, 0,
			      (void*)pqStubs, &handle);
	    Tcl_DecrRefCount(path);
	}
    }

    /* 
     * Either we've successfully loaded a library (status == TCL_OK), 
     * or we've run out of library names (in which case status==TCL_ERROR
     * and the error message reflects the last unsuccessful load attempt).
     */
    Tcl_DecrRefCount(shlibext);
    if (status != TCL_OK) {
	return NULL;
    }
    return handle;
}

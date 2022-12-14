/** This is free and unencumbered software released into the public domain.

    Anyone is free to copy, modify, publish, use, compile, sell, or
    distribute this software, either in source code form or as a compiled
    binary, for any purpose, commercial or non-commercial, and by any
    means.  **/
 /*------------------------------------------------------------------------
    File        : JiraRequestWriter
    Purpose     :
    Syntax      :
    Description :
    Author(s)   : Peter Judge / Consultingwerk Ltd
    Created     : Mon Dec 12 15:51:51 EST 2022
    Notes       :
  ----------------------------------------------------------------------*/
BLOCK-LEVEL ON ERROR UNDO, THROW.

USING OpenEdge.Net.HTTP.Filter.Payload.DefaultRequestFilter FROM PROPATH.
USING OpenEdge.Net.HTTP.IHttpRequest FROM PROPATH.

CLASS JiraRequestWriter
    INHERITS DefaultRequestFilter:

    METHOD OVERRIDE PROTECTED VOID WriteHeaders(INPUT poRequest AS IHttpRequest):
        IF  poRequest:URI:Host EQ "consultingwerk.atlassian.net":U
        AND poRequest:URI:Path BEGINS "/rest/api/":U
        THEN
            poRequest:RemoveHeader("User-Agent":U).

        SUPER:WriteHeaders(poRequest).
    END METHOD.

END CLASS.
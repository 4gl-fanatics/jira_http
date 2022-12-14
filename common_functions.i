/** This is free and unencumbered software released into the public domain.

    Anyone is free to copy, modify, publish, use, compile, sell, or
    distribute this software, either in source code form or as a compiled
    binary, for any purpose, commercial or non-commercial, and by any
    means.  **/
/*------------------------------------------------------------------------
    File        : common_functions.i
    Purpose     :

    Syntax      :

    Description :

    Author(s)   : Peter Judge / Consultingwerk Ltd
    Created     : Fri Dec 09 10:12:38 EST 2022
    Notes       :
  ----------------------------------------------------------------------*/
PROCEDURE build_client:
    DEFINE INPUT  PARAMETER pAllowTrace AS LOGICAL                       NO-UNDO.
    DEFINE OUTPUT PARAMETER pClient     AS OpenEdge.Net.HTTP.IHttpClient NO-UNDO.

    DEFINE VARIABLE lib AS OpenEdge.Net.HTTP.IHttpClientLibrary NO-UNDO.

    // -nohostverify is needed
    lib = OpenEdge.Net.HTTP.Lib.ClientLibraryBuilder:Build():sslVerifyHost(FALSE):Library.

    pClient = OpenEdge.Net.HTTP.ClientBuilder:Build()
                    :AllowTracing(pAllowTrace)
                    :UsingLibrary(lib)
                    :Client.

    /* We get a 303/See Other when asking for the attachments */
    OpenEdge.Net.HTTP.Filter.Writer.StatusCodeWriterBuilder:Registry:Put(
                        STRING(INTEGER(OpenEdge.Net.HTTP.StatusCodeEnum:SeeOther)),
                        GET-CLASS(OpenEdge.Net.HTTP.Filter.Status.RedirectStatusFilter)).

    /* Removes the User-Agent header when writing the request body */
    OpenEdge.Net.HTTP.Filter.Writer.RequestWriterBuilder:Registry:Put(
                        'HTTP/1.1':u,
                        GET-CLASS(JiraRequestWriter)).
END PROCEDURE.

PROCEDURE get_request:
    DEFINE INPUT  PARAMETER pClient      AS OpenEdge.Net.HTTP.IHttpClient           NO-UNDO.
    DEFINE INPUT  PARAMETER pURI         AS OpenEdge.Net.URI                        NO-UNDO.
    DEFINE INPUT  PARAMETER pCredentials AS OpenEdge.Net.HTTP.Credentials           NO-UNDO.
    DEFINE OUTPUT PARAMETER pData        AS Progress.Json.ObjectModel.JsonConstruct NO-UNDO.

    DEFINE VARIABLE req  AS OpenEdge.Net.HTTP.IHttpRequest  NO-UNDO.
    DEFINE VARIABLE resp AS OpenEdge.Net.HTTP.IHttpResponse NO-UNDO.

    /* paging range*/
    pURI:AddQuery ("startAt":U,"0":U).
    pURI:AddQuery ("maxResults":U,"1000":U).

    req = OpenEdge.Net.HTTP.RequestBuilder:Get (pURI)
                        :AcceptJson()
                        :UsingBasicAuthentication (pCredentials)
                        :Request.

    resp = pClient:Execute(req).

    IF TYPE-OF(resp:Entity, Progress.Json.ObjectModel.JsonConstruct) THEN
        pData = CAST(resp:Entity, Progress.Json.ObjectModel.JsonConstruct).
END PROCEDURE.

PROCEDURE put_update_request:
    DEFINE INPUT  PARAMETER pClient      AS OpenEdge.Net.HTTP.IHttpClient        NO-UNDO.
    DEFINE INPUT  PARAMETER pURI         AS OpenEdge.Net.URI                     NO-UNDO.
    DEFINE INPUT  PARAMETER pCredentials AS OpenEdge.Net.HTTP.Credentials        NO-UNDO.
    DEFINE INPUT  PARAMETER pBody        AS Progress.Json.ObjectModel.JsonObject NO-UNDO.
    DEFINE OUTPUT PARAMETER pData        AS Progress.Json.ObjectModel.JsonObject NO-UNDO.

    DEFINE VARIABLE req  AS OpenEdge.Net.HTTP.IHttpRequest  NO-UNDO.
    DEFINE VARIABLE resp AS OpenEdge.Net.HTTP.IHttpResponse NO-UNDO.

    req = OpenEdge.Net.HTTP.RequestBuilder:Put(pURI, pBody)
                        :AcceptJson()
                        :UsingBasicAuthentication (pCredentials)
                        :Request.

    resp = pClient:Execute(req).

    IF TYPE-OF(resp:Entity, Progress.Json.ObjectModel.JsonObject) THEN
        pData = CAST(resp:Entity, Progress.Json.ObjectModel.JsonObject).
END PROCEDURE.

PROCEDURE post_new_request:
    DEFINE INPUT  PARAMETER pClient      AS OpenEdge.Net.HTTP.IHttpClient        NO-UNDO.
    DEFINE INPUT  PARAMETER pURI         AS OpenEdge.Net.URI                     NO-UNDO.
    DEFINE INPUT  PARAMETER pCredentials AS OpenEdge.Net.HTTP.Credentials        NO-UNDO.
    DEFINE INPUT  PARAMETER pBody        AS Progress.Lang.Object                 NO-UNDO.
    DEFINE OUTPUT PARAMETER pData        AS Progress.Json.ObjectModel.JsonObject NO-UNDO.

    DEFINE VARIABLE req  AS OpenEdge.Net.HTTP.IHttpRequest  NO-UNDO.
    DEFINE VARIABLE resp AS OpenEdge.Net.HTTP.IHttpResponse NO-UNDO.

    req = OpenEdge.Net.HTTP.RequestBuilder:Post(pURI, pBody)
                        :AcceptJson()
                        :UsingBasicAuthentication (pCredentials)
                        // https://confluence.atlassian.com/cloudkb/xsrf-check-failed-when-calling-cloud-apis-826874382.html
                        :AddHeader("X-Atlassian-Token", "no-check")
                        :Request.

    /* Used to add attachments */
    IF TYPE-OF (pBody, OpenEdge.Net.MultipartEntity) THEN
        req:ContentType = "multipart/form-data".
    ELSE
    /* Everything else */
        req:ContentType = "application/json".

    resp = pClient:Execute(req).

    IF TYPE-OF(resp:Entity, Progress.Json.ObjectModel.JsonObject) THEN
        pData = CAST(resp:Entity, Progress.Json.ObjectModel.JsonObject).
END PROCEDURE.

PROCEDURE get_credentials:
    DEFINE OUTPUT PARAMETER pCredentials AS OpenEdge.Net.HTTP.Credentials NO-UNDO.

    DEFINE VARIABLE json AS Progress.Json.ObjectModel.JsonObject NO-UNDO.

    json = CAST(NEW Progress.Json.ObjectModel.ObjectModelParser():ParseFile("jira-credentials.json"),
                Progress.Json.ObjectModel.JsonObject).

    pCredentials = NEW OpenEdge.Net.HTTP.Credentials().
    pCredentials:Username = json:GetCharacter('user').
    pCredentials:Password = json:GetCharacter('pw').
END PROCEDURE.

PROCEDURE delete_request:
    DEFINE INPUT  PARAMETER pClient      AS OpenEdge.Net.HTTP.IHttpClient        NO-UNDO.
    DEFINE INPUT  PARAMETER pURI         AS OpenEdge.Net.URI                     NO-UNDO.
    DEFINE INPUT  PARAMETER pCredentials AS OpenEdge.Net.HTTP.Credentials        NO-UNDO.
    DEFINE INPUT  PARAMETER pBody        AS Progress.Json.ObjectModel.JsonObject NO-UNDO.
    DEFINE OUTPUT PARAMETER pData        AS Progress.Json.ObjectModel.JsonObject NO-UNDO.

    DEFINE VARIABLE req  AS OpenEdge.Net.HTTP.IHttpRequest  NO-UNDO.
    DEFINE VARIABLE resp AS OpenEdge.Net.HTTP.IHttpResponse NO-UNDO.

    req = OpenEdge.Net.HTTP.RequestBuilder:Delete(pURI, pBody)
                        :AcceptJson()
                        :UsingBasicAuthentication (pCredentials)
                        :Request.

    resp = pClient:Execute(req).

    IF TYPE-OF(resp:Entity, Progress.Json.ObjectModel.JsonObject) THEN
        pData = CAST(resp:Entity, Progress.Json.ObjectModel.JsonObject).
END PROCEDURE.

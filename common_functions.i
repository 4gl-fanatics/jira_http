
/*------------------------------------------------------------------------
    File        : common_functions.i
    Purpose     :

    Syntax      :

    Description :

    Author(s)   : Peter
    Created     : Fri Dec 09 10:12:38 EST 2022
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */


/* ********************  Preprocessor Definitions  ******************** */


/* ***************************  Main Block  *************************** */
PROCEDURE build_client:
    DEFINE OUTPUT PARAMETER pClient AS OpenEdge.Net.HTTP.IHttpClient NO-UNDO.

    DEFINE VARIABLE lib AS OpenEdge.Net.HTTP.IHttpClientLibrary NO-UNDO.

    // -nohostverify needed
    lib = OpenEdge.Net.HTTP.Lib.ClientLibraryBuilder:Build():sslVerifyHost(NO):Library.
    pClient = OpenEdge.Net.HTTP.ClientBuilder:Build()
                    :AllowTracing(true)
                    :UsingLibrary(lib)
                    :Client.

    // We get a 303/See Other when asking for the attachments
    OpenEdge.Net.HTTP.Filter.Writer.StatusCodeWriterBuilder:Registry:Put(
                        STRING(INTEGER(OpenEdge.Net.HTTP.StatusCodeEnum:SeeOther)),
                        GET-CLASS(OpenEdge.Net.HTTP.Filter.Status.RedirectStatusFilter)).
END PROCEDURE.

PROCEDURE get_request:
    DEFINE INPUT  PARAMETER pClient AS OpenEdge.Net.HTTP.IHttpClient NO-UNDO.
    DEFINE INPUT  PARAMETER pURI AS OpenEdge.Net.URI NO-UNDO.
    DEFINE INPUT  PARAMETER pCredentials AS OpenEdge.Net.HTTP.Credentials NO-UNDO.
    DEFINE OUTPUT PARAMETER pData AS Progress.Json.ObjectModel.JsonObject NO-UNDO.

    DEFINE VARIABLE req AS OpenEdge.Net.HTTP.IHttpRequest NO-UNDO.
    DEFINE VARIABLE resp AS OpenEdge.Net.HTTP.IHttpResponse NO-UNDO.

    pURI:AddQuery ("startAt":U,"0":U).
    pURI:AddQuery ("maxResults":U,"1000":U).

    req = OpenEdge.Net.HTTP.RequestBuilder:Get (pURI)
                        :AcceptJson()
                        :UsingBasicAuthentication (pCredentials)
                        :Request.

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